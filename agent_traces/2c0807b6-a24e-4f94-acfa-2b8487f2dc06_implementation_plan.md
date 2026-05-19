# Goal: Fill gaps between frontend and backend for Meals and Custom Workouts

The backend has recently updated the `nutrition_meals` related tables to include more detailed information such as ingredients, health compatibility, allergens, prep/cook time, and portion descriptions. Additionally, the Custom Workout generator's API schema has been updated to accept specific fields like `target_body_parts`, `preferred_environment`, etc., and enforces strict capitalization.

We will update the frontend screens to correctly map to these new backend structures, while maintaining the existing beautiful app theme.

## Open Questions
- For the `mealDetalScreen.js`, should we display all health compatibility conditions regardless of their status (e.g., "Suitable", "Caution"), or only show the ones that have a status? (I will assume we should display all provided conditions that have a status for now).

## Proposed Changes

---

### Custom Workout Wizard (`CustomWorkoutWizard.jsx`)

The API payload constructed in `CustomWorkoutWizard.jsx` does not perfectly match the `GenerateWorkoutRequest` schema defined in `workout_schema.py`.

#### [MODIFY] `CustomWorkoutWizard.jsx`
- Fix the `payload` property names in `handleGenerate` to match backend expectations:
  - `symptoms` $\rightarrow$ `current_symptoms`
  - `target_area` $\rightarrow$ `target_body_parts` (and wrap `targetArea` in an array, as backend expects `List[str]`)
  - `environment` $\rightarrow$ `preferred_environment`
  - `break_duration_seconds` $\rightarrow$ `preferred_break_duration`
  - `equipment` $\rightarrow$ `available_equipment`
  - Change `default_intensity` to pass the exact string ("Low", "Medium", "Hard") rather than `.toLowerCase()`.

---

### Meal Detail Screen (`mealDetalScreen.js`)

The `MealDetailFullResponse` from the backend now returns much more comprehensive data. We need to display this information to the user using the existing `AccordionSection` UI pattern.

#### [MODIFY] `mealDetalScreen.js`
- **Stats Row**: Add `prep_time_minutes` and `cook_time_minutes` (using `timer-sand` or `chef-hat` icons) to the pill cluster below the title.
- **Portion Description**: Display the `portion_description` if available, perhaps above the Nutrients section.
- **Ingredients Accordion**: Add a new `AccordionSection` (Icon: `food-apple-outline`) to iterate over the `ingredients` array and display `quantity`, `unit`, `ingredient_name`, and any `pcos_benefit`.
- **Allergens Accordion**: Add a new `AccordionSection` (Icon: `alert-circle-outline`) to display `allergen_warnings` and `recommended_substitutions` from the `allergen` object.
- **Health Compatibility Accordion**: Add a new `AccordionSection` (Icon: `heart-pulse`) to list out statuses for conditions like `diabetes_type_2`, `hypertension`, etc., with corresponding warning/success icons and notes.

## Verification Plan

### Manual Verification
- Review the `CustomWorkoutWizard.jsx` to ensure `handleGenerate` builds the correct payload for the API.
- Review `mealDetalScreen.js` to ensure the new accordions and stat pills correctly safely map data (handling `null` or `undefined` arrays gracefully).
- Confirm the new UI sections blend perfectly with the existing premium styling (using `COLORS.primary`, shadow constants, etc.).
