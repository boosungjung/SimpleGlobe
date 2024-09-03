//
//  Globe+Preview.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/3/2024.
//

import Foundation

//#if DEBUG
extension Globe {
    
    /// A globe for previewing SwiftUI views.
    static var preview: Globe {
        Globe(
            name: "Bellerby World Globe",
            shortName: "World Globe",
            nameTranslated: nil,
            authorSurname: "Peter",
            authorFirstName: "Bellerby",
            date: "2023",
            description: "Peter Bellerby makes modern globes with old world craftsmanship. Many consider him the finest living globe maker.",
            infoURL: URL(string: "https://www.davidrumsey.com/luna/servlet/s/cd8p41"),
            radius: 0.325,
            texture: "Bellerby65cmSchminkeGagarin"
        )
    }
}
//#endif
