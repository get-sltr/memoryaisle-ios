import SwiftUI

enum GroceryListSeed {
    static func defaultList() -> [GroceryCategory] {
        [
            GroceryCategory(name: "Protein", icon: "flame.fill", color: 0xA78BFA, items: [
                GroceryItem(name: "Chicken breast", quantity: "2 lbs", proteinPer: "31g/4oz"),
                GroceryItem(name: "Salmon fillets", quantity: "1 lb", proteinPer: "23g/4oz"),
                GroceryItem(name: "Eggs (dozen)", quantity: "1", proteinPer: "6g each"),
                GroceryItem(name: "Greek yogurt", quantity: "32 oz", proteinPer: "15g/cup"),
                GroceryItem(name: "Whey protein", quantity: "1 tub", proteinPer: "25g/scoop")
            ]),
            GroceryCategory(name: "Dairy", icon: "cup.and.saucer.fill", color: 0x38BDF8, items: [
                GroceryItem(name: "Cottage cheese", quantity: "16 oz", proteinPer: "14g/cup"),
                GroceryItem(name: "Almond milk", quantity: "1/2 gal", proteinPer: nil),
                GroceryItem(name: "Parmesan", quantity: "4 oz", proteinPer: nil)
            ]),
            GroceryCategory(name: "Produce", icon: "carrot.fill", color: 0x34D399, items: [
                GroceryItem(name: "Broccoli", quantity: "2 heads", proteinPer: nil),
                GroceryItem(name: "Spinach", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Bananas", quantity: "6", proteinPer: nil),
                GroceryItem(name: "Berries (mixed)", quantity: "1 pint", proteinPer: nil),
                GroceryItem(name: "Avocados", quantity: "3", proteinPer: nil),
                GroceryItem(name: "Sweet potatoes", quantity: "3", proteinPer: nil)
            ]),
            GroceryCategory(name: "Grains", icon: "leaf.fill", color: 0xFBBF24, items: [
                GroceryItem(name: "Brown rice", quantity: "2 lbs", proteinPer: nil),
                GroceryItem(name: "Quinoa", quantity: "1 lb", proteinPer: "8g/cup"),
                GroceryItem(name: "Oats", quantity: "18 oz", proteinPer: "5g/cup")
            ]),
            GroceryCategory(name: "Pantry", icon: "bag.fill", color: 0xFCA5A5, items: [
                GroceryItem(name: "Hemp seeds", quantity: "8 oz", proteinPer: "10g/3tbsp"),
                GroceryItem(name: "Almond butter", quantity: "1 jar", proteinPer: "7g/2tbsp"),
                GroceryItem(name: "Chia seeds", quantity: "6 oz", proteinPer: "5g/2tbsp"),
                GroceryItem(name: "Ginger tea", quantity: "1 box", proteinPer: nil)
            ]),
            GroceryCategory(name: "Frozen", icon: "snowflake", color: 0x67E8F9, items: [
                GroceryItem(name: "Frozen berries", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Frozen broccoli", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Frozen chicken", quantity: "2 lbs", proteinPer: "31g/4oz")
            ])
        ]
    }
}
