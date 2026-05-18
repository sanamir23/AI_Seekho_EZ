from __future__ import annotations

import logging
from datetime import datetime

from app.agents import tools as T

log = logging.getLogger("scheduler.jobs")


def dispatch_notification(notification_id: str) -> None:
    """Fired by APScheduler at the scheduled time. Mocks sending the reminder."""
    log.info("[REMINDER FIRED] notification_id=%s", notification_id)
    T.mark_notification_sent(notification_id)


def requeue_due_notifications() -> None:
    """On boot, re-add scheduler jobs for any unsent future notifications."""
    from app.scheduler.runtime import schedule_reminder

    for n in T.list_due_notifications():
        try:
            run_at = datetime.fromisoformat(n["scheduled_at"].replace("Z", "+00:00"))
            schedule_reminder(notification_id=n["id"], run_at=run_at)
        except Exception as e:  # don't crash boot on a malformed row
            log.warning("Failed to requeue notification %s: %s", n.get("id"), e)
