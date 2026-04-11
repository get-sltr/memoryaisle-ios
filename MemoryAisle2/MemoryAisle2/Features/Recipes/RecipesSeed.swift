import SwiftUI

enum RecipesSeed {
    static var all: [RecipeItem] {
        [
            overnightOats,
            chickenBowl,
            salmonSweetPotato,
            tunaLettuceWraps,
            turkeyMeatballs,
            greenSmoothie,
            chickenRiceMealPrep
        ]
    }

    // MARK: - Individual recipes

    private static var overnightOats: RecipeItem {
        RecipeItem(
            name: "Protein Overnight Oats",
            category: .breakfast, protein: 32, calories: 380,
            prepTime: "5 min", cookTime: "None", servings: 1, nauseaSafe: true,
            ingredients: [
                Ingredient(name: "Greek yogurt (plain, 2%)", amount: "3/4 cup", prep: nil),
                Ingredient(name: "Rolled oats", amount: "1/2 cup", prep: nil),
                Ingredient(name: "Chia seeds", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Hemp hearts", amount: "2 tbsp", prep: nil),
                Ingredient(name: "Mixed berries", amount: "1/2 cup", prep: "fresh or frozen"),
                Ingredient(name: "Honey", amount: "1 tsp", prep: "optional"),
                Ingredient(name: "Almond milk", amount: "1/4 cup", prep: nil)
            ],
            steps: [
                CookingStep(number: 1, instruction: "In a mason jar or container, combine the Greek yogurt and almond milk. Stir until smooth.", duration: nil, tip: nil),
                CookingStep(number: 2, instruction: "Add the rolled oats, chia seeds, and hemp hearts. Mix thoroughly so everything is coated.", duration: nil, tip: "Hemp hearts add 10g protein with almost no taste."),
                CookingStep(number: 3, instruction: "Top with berries and drizzle honey if using. Do not stir the berries in.", duration: nil, tip: nil),
                CookingStep(number: 4, instruction: "Seal the container and refrigerate overnight, or at least 4 hours.", duration: "4+ hours", tip: "Make 3-5 jars on Sunday for the whole week."),
                CookingStep(number: 5, instruction: "Eat cold straight from the fridge. Stir once before eating.", duration: nil, tip: "Cold foods are easier on nausea days.")
            ],
            description: "No-cook, high-protein breakfast. Prep the night before, grab and eat. The chia seeds thicken overnight into a pudding-like texture.",
            miraTip: "32g protein before you even think about it. On nausea days, skip the honey and use frozen berries for a colder, more soothing texture."
        )
    }

    private static var chickenBowl: RecipeItem {
        RecipeItem(
            name: "Grilled Chicken Power Bowl",
            category: .lunch, protein: 45, calories: 580,
            prepTime: "10 min", cookTime: "15 min", servings: 1, nauseaSafe: false,
            ingredients: [
                Ingredient(name: "Chicken breast", amount: "6 oz", prep: "sliced into 1/2 inch strips"),
                Ingredient(name: "Brown rice", amount: "3/4 cup", prep: "cooked"),
                Ingredient(name: "Avocado", amount: "1/2", prep: "sliced"),
                Ingredient(name: "Mixed greens", amount: "1 cup", prep: nil),
                Ingredient(name: "Cherry tomatoes", amount: "6", prep: "halved"),
                Ingredient(name: "Lemon", amount: "1/2", prep: "juiced"),
                Ingredient(name: "Tahini", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Olive oil", amount: "1 tsp", prep: nil),
                Ingredient(name: "Salt and pepper", amount: "to taste", prep: nil)
            ],
            steps: [
                CookingStep(number: 1, instruction: "Season chicken strips with salt, pepper, and a squeeze of lemon juice.", duration: nil, tip: nil),
                CookingStep(number: 2, instruction: "Heat olive oil in a skillet or grill pan over medium-high heat until it shimmers.", duration: "1 min", tip: nil),
                CookingStep(number: 3, instruction: "Cook chicken strips 4-5 minutes per side until internal temperature reaches 165F. The outside should have light char marks.", duration: "8-10 min", tip: "Don't move the chicken around. Let it sear."),
                CookingStep(number: 4, instruction: "While chicken rests, build the bowl: rice on the bottom, greens on one side.", duration: nil, tip: "Let chicken rest 3 minutes before slicing. This keeps it juicy."),
                CookingStep(number: 5, instruction: "Slice the rested chicken and arrange on the bowl. Add avocado slices and tomatoes.", duration: nil, tip: nil),
                CookingStep(number: 6, instruction: "Mix tahini with remaining lemon juice and 1 tbsp water. Drizzle over the bowl.", duration: nil, tip: "The tahini dressing adds healthy fats and makes it taste restaurant-quality.")
            ],
            description: "The muscle-preservation lunch. 45g protein from chicken breast, healthy fats from avocado, complex carbs from brown rice.",
            miraTip: "This is your go-to on training days. The carbs fuel your workout, the protein rebuilds. Skip avocado on high-nausea days."
        )
    }

    private static var salmonSweetPotato: RecipeItem {
        RecipeItem(
            name: "Salmon with Roasted Sweet Potato",
            category: .dinner, protein: 38, calories: 520,
            prepTime: "10 min", cookTime: "25 min", servings: 1, nauseaSafe: false,
            ingredients: [
                Ingredient(name: "Salmon fillet (skin-on)", amount: "6 oz", prep: "patted dry"),
                Ingredient(name: "Sweet potato", amount: "1 medium", prep: "cut into 1/2 inch cubes"),
                Ingredient(name: "Broccoli florets", amount: "1 cup", prep: "cut into bite-size pieces"),
                Ingredient(name: "Olive oil", amount: "2 tsp", prep: nil),
                Ingredient(name: "Garlic powder", amount: "1/2 tsp", prep: nil),
                Ingredient(name: "Lemon", amount: "1/2", prep: "cut into wedges"),
                Ingredient(name: "Salt and pepper", amount: "to taste", prep: nil)
            ],
            steps: [
                CookingStep(number: 1, instruction: "Preheat oven to 425F. Line a baking sheet with parchment paper.", duration: nil, tip: nil),
                CookingStep(number: 2, instruction: "Toss sweet potato cubes with 1 tsp olive oil, salt, and garlic powder. Spread in a single layer on one side of the baking sheet.", duration: nil, tip: "Single layer is key. Crowded potatoes steam instead of roast."),
                CookingStep(number: 3, instruction: "Roast sweet potatoes alone for 10 minutes.", duration: "10 min", tip: nil),
                CookingStep(number: 4, instruction: "Remove sheet. Add broccoli to the other side, tossed with remaining olive oil and salt. Place salmon fillet skin-side down in the center.", duration: nil, tip: nil),
                CookingStep(number: 5, instruction: "Season salmon with salt, pepper, and a squeeze of lemon.", duration: nil, tip: "Don't overcook salmon. It should be slightly translucent in the center."),
                CookingStep(number: 6, instruction: "Return to oven and roast for 12-15 minutes until salmon flakes easily with a fork.", duration: "12-15 min", tip: nil),
                CookingStep(number: 7, instruction: "Serve with lemon wedges. The skin should be crispy and peel off easily.", duration: nil, tip: "Omega-3s in salmon reduce inflammation. Eat this 2-3 times per week.")
            ],
            description: "One-pan dinner. Omega-3 rich salmon with complex carbs from sweet potato and fiber from broccoli. Everything roasts together.",
            miraTip: "38g protein plus omega-3 fatty acids that help with inflammation. On rest days, swap the sweet potato for extra broccoli to reduce carbs."
        )
    }

    private static var tunaLettuceWraps: RecipeItem {
        RecipeItem(
            name: "Tuna Lettuce Wraps",
            category: .lunch, protein: 35, calories: 280,
            prepTime: "5 min", cookTime: "None", servings: 2, nauseaSafe: true,
            ingredients: [
                Ingredient(name: "Canned tuna (in water)", amount: "2 cans (5 oz each)", prep: "drained"),
                Ingredient(name: "Greek yogurt", amount: "2 tbsp", prep: "instead of mayo"),
                Ingredient(name: "Celery", amount: "1 stalk", prep: "diced small"),
                Ingredient(name: "Lemon juice", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Butter lettuce leaves", amount: "6 large", prep: "washed and dried"),
                Ingredient(name: "Everything bagel seasoning", amount: "1 tsp", prep: "optional")
            ],
            steps: [
                CookingStep(number: 1, instruction: "Drain both cans of tuna and add to a bowl. Break apart with a fork until flaky.", duration: nil, tip: nil),
                CookingStep(number: 2, instruction: "Add Greek yogurt, diced celery, and lemon juice. Mix until combined.", duration: nil, tip: "Greek yogurt replaces mayo. Same creamy texture, way more protein, easier on the stomach."),
                CookingStep(number: 3, instruction: "Season with salt, pepper, and everything bagel seasoning if using.", duration: nil, tip: nil),
                CookingStep(number: 4, instruction: "Spoon the tuna mixture into lettuce cups. About 2-3 tablespoons per wrap.", duration: nil, tip: "Butter lettuce works best. It's soft and cups naturally. Romaine is too rigid."),
                CookingStep(number: 5, instruction: "Eat immediately, or store tuna mixture separately in the fridge for up to 2 days.", duration: nil, tip: nil)
            ],
            description: "Zero cooking, 5 minutes, 35g protein. Greek yogurt instead of mayo keeps it light and nausea-friendly.",
            miraTip: "Perfect for nausea days. Cold, light, no strong smells. The lemon cuts any fishy taste. Keep canned tuna stocked at all times."
        )
    }

    private static var turkeyMeatballs: RecipeItem {
        RecipeItem(
            name: "Turkey Meatballs with Zucchini Noodles",
            category: .dinner, protein: 42, calories: 380,
            prepTime: "15 min", cookTime: "20 min", servings: 2, nauseaSafe: false,
            ingredients: [
                Ingredient(name: "Ground turkey (93% lean)", amount: "1 lb", prep: nil),
                Ingredient(name: "Egg", amount: "1", prep: "beaten"),
                Ingredient(name: "Garlic", amount: "3 cloves", prep: "minced"),
                Ingredient(name: "Parmesan cheese", amount: "2 tbsp", prep: "grated"),
                Ingredient(name: "Italian seasoning", amount: "1 tsp", prep: nil),
                Ingredient(name: "Zucchini", amount: "2 large", prep: "spiralized into noodles"),
                Ingredient(name: "Marinara sauce", amount: "1 cup", prep: "low sugar"),
                Ingredient(name: "Olive oil", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Salt and pepper", amount: "to taste", prep: nil)
            ],
            steps: [
                CookingStep(number: 1, instruction: "In a large bowl, combine ground turkey, beaten egg, minced garlic, parmesan, Italian seasoning, salt, and pepper. Mix with your hands until just combined.", duration: nil, tip: "Don't overmix. Overworked meatballs get tough and chewy."),
                CookingStep(number: 2, instruction: "Roll into 12 meatballs, about 1.5 inches each. Wet your hands slightly to prevent sticking.", duration: nil, tip: nil),
                CookingStep(number: 3, instruction: "Heat olive oil in a large skillet over medium heat. Add meatballs and cook, turning every 2-3 minutes until browned on all sides.", duration: "8-10 min", tip: nil),
                CookingStep(number: 4, instruction: "Pour marinara sauce over the meatballs. Reduce heat to low, cover, and simmer for 10 minutes until cooked through.", duration: "10 min", tip: "Internal temp should reach 165F."),
                CookingStep(number: 5, instruction: "While meatballs simmer, add zucchini noodles to a separate pan over medium heat. Cook 2-3 minutes until just tender.", duration: "2-3 min", tip: "Don't overcook zoodles. They release water and get mushy. Just warm them through."),
                CookingStep(number: 6, instruction: "Serve meatballs and sauce over zucchini noodles. Top with extra parmesan.", duration: nil, tip: "Freeze extra meatballs in sauce. Reheat for a 3-minute dinner.")
            ],
            description: "Low-carb, high-protein dinner. Turkey meatballs in marinara over zucchini noodles. Freeze extras for meal prep.",
            miraTip: "42g protein per serving. Make a double batch and freeze half. Future you will thank present you on a low-energy day."
        )
    }

    private static var greenSmoothie: RecipeItem {
        RecipeItem(
            name: "High-Protein Green Smoothie",
            category: .smoothie, protein: 30, calories: 320,
            prepTime: "3 min", cookTime: "None", servings: 1, nauseaSafe: true,
            ingredients: [
                Ingredient(name: "Protein powder (vanilla)", amount: "1 scoop", prep: nil),
                Ingredient(name: "Baby spinach", amount: "1 large handful", prep: nil),
                Ingredient(name: "Banana", amount: "1/2", prep: "frozen"),
                Ingredient(name: "Almond milk (unsweetened)", amount: "1 cup", prep: nil),
                Ingredient(name: "Peanut butter", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Ice", amount: "4-5 cubes", prep: nil)
            ],
            steps: [
                CookingStep(number: 1, instruction: "Add almond milk to the blender first, then spinach. Blend for 10 seconds until spinach is broken down.", duration: "10 sec", tip: "Liquid first prevents the blender from jamming."),
                CookingStep(number: 2, instruction: "Add frozen banana, protein powder, peanut butter, and ice.", duration: nil, tip: "Frozen banana makes it thick like a milkshake. Fresh banana makes it thin."),
                CookingStep(number: 3, instruction: "Blend on high for 30-45 seconds until completely smooth. No green chunks should be visible.", duration: "30-45 sec", tip: nil),
                CookingStep(number: 4, instruction: "Pour and drink immediately. Smoothies separate if they sit.", duration: nil, tip: "Sip slowly on nausea days. The cold temperature helps settle your stomach.")
            ],
            description: "Drinkable protein for days when eating feels hard. The spinach is invisible but adds iron and micronutrients.",
            miraTip: "30g protein you can sip. On high-nausea days, this might be the only way to hit your target. The cold helps."
        )
    }

    private static var chickenRiceMealPrep: RecipeItem {
        RecipeItem(
            name: "5-Day Chicken and Rice Meal Prep",
            category: .mealPrep, protein: 40, calories: 480,
            prepTime: "15 min", cookTime: "35 min", servings: 5, nauseaSafe: false,
            ingredients: [
                Ingredient(name: "Chicken thighs (boneless, skinless)", amount: "2 lbs", prep: "trimmed of excess fat"),
                Ingredient(name: "Jasmine rice", amount: "2 cups", prep: "uncooked"),
                Ingredient(name: "Broccoli", amount: "2 large heads", prep: "cut into florets"),
                Ingredient(name: "Soy sauce (low sodium)", amount: "3 tbsp", prep: nil),
                Ingredient(name: "Sesame oil", amount: "1 tbsp", prep: nil),
                Ingredient(name: "Garlic powder", amount: "1 tsp", prep: nil),
                Ingredient(name: "Sriracha", amount: "to taste", prep: "optional")
            ],
            steps: [
                CookingStep(number: 1, instruction: "Cook rice according to package directions. For jasmine rice: 2 cups rice + 2.5 cups water, bring to boil, reduce to low, cover 15 minutes.", duration: "15 min", tip: nil),
                CookingStep(number: 2, instruction: "While rice cooks, season chicken thighs with garlic powder, salt, pepper, and 1 tbsp soy sauce.", duration: nil, tip: "Thighs are more forgiving than breasts. They stay moist even reheated."),
                CookingStep(number: 3, instruction: "Heat a large skillet over medium-high. Cook chicken 5-6 minutes per side until golden and cooked through (165F internal).", duration: "10-12 min", tip: nil),
                CookingStep(number: 4, instruction: "Remove chicken and let rest 5 minutes. In the same pan, add broccoli with remaining soy sauce and sesame oil. Cook 4-5 minutes until bright green and slightly tender.", duration: "4-5 min", tip: "Use the chicken drippings for flavor. Don't wash the pan."),
                CookingStep(number: 5, instruction: "Slice chicken into strips. Divide rice, chicken, and broccoli evenly into 5 meal prep containers.", duration: nil, tip: nil),
                CookingStep(number: 6, instruction: "Add sriracha to each container if desired. Refrigerate. Keeps 4-5 days. Reheat 2 minutes in microwave.", duration: nil, tip: "45 minutes of work = 5 lunches. That's 200g of protein sorted for the week.")
            ],
            description: "One hour on Sunday, five lunches done. 40g protein per container. The most efficient way to hit your targets consistently.",
            miraTip: "This is the single most impactful recipe for protein compliance. People who meal prep hit their targets 3x more often."
        )
    }
}
