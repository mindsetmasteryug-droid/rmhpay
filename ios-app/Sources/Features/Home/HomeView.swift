import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                AccountLookupView()
            }
            .tabItem {
                Label("Lookup", systemImage: "magnifyingglass")
            }
            .tag(0)

            NavigationView {
                SavedAccountsView()
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark.fill")
            }
            .tag(1)

            NavigationView {
                ReceiptsView()
            }
            .tabItem {
                Label("Receipts", systemImage: "doc.text.fill")
            }
            .tag(2)

            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        List {
            if let user = authService.currentUser {
                Section {
                    HStack {
                        Text("Phone")
                        Spacer()
                        Text(user.phoneNumber)
                            .foregroundColor(.secondary)
                    }

                    if let name = user.fullName {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(name)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let email = user.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                Button(action: {
                    authService.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Profile")
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading = false
}
