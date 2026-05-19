from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler

log = logging.getLogger("scheduler")

_scheduler: Optional[BackgroundScheduler] = None


def start_scheduler() -> BackgroundScheduler:
    global _scheduler
    if _scheduler and _scheduler.running:
        return _scheduler
    # BackgroundScheduler runs in its own thread — never blocks the event loop.
    # Crash durability is handled by requeue_due_notifications() below, which
    # re-adds jobs for any unsent notifications already committed to the DB.
    _scheduler = BackgroundScheduler(timezone="UTC")
    _scheduler.start()
    log.info("APScheduler started.")
    from app.scheduler.jobs import requeue_due_notifications, expire_holds_job
    requeue_due_notifications()
    # Cleanup expired slot holds every 30 seconds.
    _scheduler.add_job(
        expire_holds_job,
        trigger="interval",
        seconds=30,
        id="expire_holds",
        replace_existing=True,
    )
    return _scheduler


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        log.info("APScheduler stopped.")


def get_scheduler() -> BackgroundScheduler:
    if _scheduler is None:
        raise RuntimeError("Scheduler not started. Call start_scheduler() first.")
    return _scheduler


def schedule_reminder(notification_id: str, run_at: datetime) -> str:
    """Register a date job that will dispatch the given notification at run_at.

    Returns the APScheduler job id. Job id == notification id for easy cancel.
    """
    from app.scheduler.jobs import dispatch_notification
    sched = get_scheduler()
    job = sched.add_job(
        dispatch_notification,
        trigger="date",
        run_date=run_at,
        args=[notification_id],
        id=f"notif:{notification_id}",
        replace_existing=True,
        misfire_grace_time=3600,
    )
    log.info("Scheduled reminder %s at %s", notification_id, run_at.isoformat())
    return job.id


def cancel_reminder(notification_id: str) -> None:
    try:
        get_scheduler().remove_job(f"notif:{notification_id}")
    except Exception:
        pass
