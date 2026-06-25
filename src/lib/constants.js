// Planned meal checklist (NOT the calorie log — actual macros come from daily_logs)
export const MEALS = [
  { key: "breakfast", name: "Breakfast", time: "7:15 AM", cal: 520, protein: 38 },
  { key: "lunch", name: "Lunch", time: "12:30 PM", cal: 650, protein: 55 },
  { key: "snack", name: "Pre-gym snack", time: "5:00 PM", cal: 320, protein: 22 },
  { key: "dinner", name: "Dinner", time: "7:30 PM", cal: 600, protein: 45 },
];

// Quick-add preset foods for the Log tab
export const PRESET_FOODS = [
  { name: "Salmon 6 oz", calories: 240, protein: 34, carbs: 0, fat: 11 },
  { name: "Chicken breast 8 oz", calories: 370, protein: 70, carbs: 0, fat: 8 },
  { name: "Ground beef 90/10 6 oz", calories: 310, protein: 46, carbs: 0, fat: 14 },
  { name: "2 eggs", calories: 140, protein: 12, carbs: 1, fat: 10 },
  { name: "Oatmeal 1 cup dry", calories: 300, protein: 10, carbs: 54, fat: 6 },
  { name: "Whey 1 scoop", calories: 120, protein: 25, carbs: 3, fat: 2 },
  { name: "Rice 1 cup cooked", calories: 205, protein: 4, carbs: 45, fat: 0 },
  { name: "Banana", calories: 110, protein: 1, carbs: 27, fat: 0 },
  { name: "Peanut butter 1 tbsp", calories: 95, protein: 4, carbs: 3, fat: 8 },
  { name: "Blueberries 1 cup", calories: 85, protein: 1, carbs: 21, fat: 0 },
  { name: "Rice cakes", calories: 70, protein: 1, carbs: 14, fat: 0 },
  { name: "Greek yogurt 1 cup", calories: 150, protein: 20, carbs: 8, fat: 0 },
];

export const CHECKIN_SLIDERS = [
  { key: "energy", label: "Energy" },
  { key: "pt_recovery", label: "PT recovery" },
  { key: "hunger", label: "Hunger" },
  { key: "sleep", label: "Sleep" },
  { key: "swelling", label: "Swelling" },
];

// ---- PLAN tab content ----
export const PLAN_MACROS = [
  { label: "Calories", value: "2550", unit: "/day" },
  { label: "Protein", value: "190g", unit: "/day" },
  { label: "Carbs", value: "285g", unit: "/day" },
  { label: "Fat", value: "75g", unit: "/day" },
  { label: "Water", value: "110oz", unit: "/day" },
];

export const RECOVERY_STACK = [
  { item: "Collagen peptides", detail: "15g" },
  { item: "Vitamin C", detail: "50–100mg" },
  { item: "Timing", detail: "30–60 min before PT/lifting" },
  { item: "Creatine", detail: "5g/day" },
  { item: "Vitamin D3", detail: "2000 IU/day" },
  { item: "Hydration", detail: "110–130 oz/day" },
];

export const RTS_PHASES = [
  { n: 1, title: "Early rehab / reduced activity", cals: "2400–2550 cal", carbs: "250–285g carbs" },
  { n: 2, title: "Full weight bearing", cals: "2550–2650 cal", carbs: "285–315g carbs" },
  { n: 3, title: "Strength training ramp", cals: "2650–2700 cal", carbs: "315–340g carbs" },
  { n: 4, title: "Running progression", cals: "2700–2800 cal", carbs: "340–360g carbs" },
  { n: 5, title: "Return to sport", cals: "2800–2900 cal", carbs: "360–380g carbs" },
];

export const BATCH_PREP = [
  "Chicken",
  "Beef",
  "Salmon",
  "Eggs",
  "Rice",
  "Sweet potatoes",
  "Broccoli",
  "Carrots",
  "Greek yogurt stocked",
  "Bananas stocked",
  "Blueberries stocked",
  "Rice cakes stocked",
];

export const BUDGET_STAPLES = [
  "Chicken breast/thighs",
  "Lean beef",
  "Eggs",
  "Greek yogurt",
  "Oats",
  "Rice",
  "Bananas",
  "Frozen broccoli",
  "Carrots",
  "Peanut butter",
  "Whey protein",
  "Frozen salmon when budget allows",
];

export const SUCCESS_RULES = [
  "Hit 190g protein",
  "Hit 110 oz water",
  "Take collagen before PT/lifting",
  "Eat carbs around training",
  "Do not crash diet during tendon healing",
  "Track check-ins every 14 days",
];
