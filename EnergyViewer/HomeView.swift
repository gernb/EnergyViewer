//
//  HomeView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct HomeView<ViewModel: HomeViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        ContentView(viewModel: viewModel)
            .alert(item: $viewModel.alert) { item in
                Alert(title: Text(item.title),
                      message: Text(item.text),
                      dismissButton: .cancel(Text(item.buttonText), action: item.action ?? {}))
            }
    }
}

fileprivate struct ContentView<ViewModel: HomeViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            return AnyView(
                VStack {
                    Wrap(UIActivityIndicatorView()) {
                        $0.startAnimating()
                        $0.color = .systemBlue
                    }
                    Text("Loading...")
                }
            )

        case .loggedIn(let siteName, let powerStatusVM, let powerHistoryVM):
            return AnyView(
                ZStack {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { self.viewModel.logout() }) {
                                Text("Logout")
                            }.padding(.trailing)
                        }
                        Spacer()
                    }
                    VStack {
                        Text("Site: \(siteName)")
                        Spacer()
                        PowerStatusView(viewModel: powerStatusVM, showRawStatus: false)
                        Divider()
                        PowerHistoryView(viewModel: powerHistoryVM)
                    }
                }
            )

        case .loggedOut:
            return AnyView(
                Button(action: { self.viewModel.showSignIn.toggle() })  {
                    Text("Sign in")
                }.sheet(isPresented: $viewModel.showSignIn) {
                    SignInView(userManager: self.viewModel.userManager, api: self.viewModel.api)
                }
            )
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            Group {
                HomeView(viewModel: PreviewHomeViewModel.loggedOut)
                
                HomeView(viewModel: PreviewHomeViewModel.loading)
                
                HomeView(viewModel: PreviewHomeViewModel.loggedIn)
                
                HomeView(viewModel: PreviewHomeViewModel.loggedInLoading)
            }
            .preferredColorScheme(colorScheme)
            .previewDisplayName("\(colorScheme)")
        }
        .previewLayout(.fixed(width: 1194, height: 834))
    }

    final class PreviewHomeViewModel: HomeViewModel {
        typealias State = HomeViewModelState<PowerStatusView_Previews.PreviewPowerStatusViewModel, PowerHistoryView_Previews.PreviewPowerHistoryViewModel>
        var userManager = UserManager()
        var api = TeslaApi()
        var state: State
        var showSignIn: Bool
        var alert: AlertItem?

        init(state: State, showSignIn: Bool = false) {
            self.state = state
            self.showSignIn = showSignIn
        }

        func logout() {}

        static let loggedOut = PreviewHomeViewModel(state: .loggedOut, showSignIn: true)
        static let loading = PreviewHomeViewModel(state: .loading)
        static let loggedIn = PreviewHomeViewModel(state: .loggedIn(siteName: "Preview",
                                                    PowerStatusView_Previews.PreviewPowerStatusViewModel(),
                                                    PowerHistoryView_Previews.PreviewPowerHistoryViewModel()))
        static let loggedInLoading = PreviewHomeViewModel(state: .loggedIn(siteName: "Preview",
                                                                           PowerStatusView_Previews.loadingState,
                                                                           PowerHistoryView_Previews.loadingState))
    }
}
