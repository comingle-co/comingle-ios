//
//  CalendarsView.swift
//  Comingle
//
//  Created by Terry Yiu on 8/16/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct CalendarsView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            let calendarListEvents = Array(appState.calendarListEvents.filter { !$0.value.calendarEventCoordinateList.isEmpty })
            ForEach(calendarListEvents, id: \.key) { coordinates, calendarListEvent in
                Section(
                    content: {
                        NavigationLink(destination: {
                            CalendarListEventView(calendarListEventCoordinates: coordinates)
                        }, label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(calendarListEvent.title?.trimmedOrNilIfEmpty ?? calendarListEvent.firstValueForRawTagName("name")?.trimmedOrNilIfEmpty ?? "No Title")
                                        .font(.headline)

                                    Divider()

                                    ProfilePictureAndNameView(publicKeyHex: calendarListEvent.pubkey)
                                }
                                if let imageURL = calendarListEvent.imageURL {
                                    KFImage.url(imageURL)
                                        .resizable()
                                        .placeholder { ProgressView() }
                                        .scaledToFit()
                                        .frame(maxWidth: 100, maxHeight: 200)
                                }
                            }
                        })
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
//    CalendarsView()
//}
