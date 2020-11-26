//
//  HomeView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/11/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI
import TeslaAPI

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
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    @ViewBuilder
    var body: some View {
        switch viewModel.state {
        case .loading:
            loadingContent

        case .loggedIn(let siteName, let powerStatusVM, let powerHistoryVM):
            if isPhone {
                ScrollView {
                    loggedInContent(siteName: siteName, powerStatusVM: powerStatusVM, powerHistoryVM: powerHistoryVM)
                }
            } else {
                loggedInContent(siteName: siteName, powerStatusVM: powerStatusVM, powerHistoryVM: powerHistoryVM)
            }

        case .loggedOut:
            loggedOutContent
        }
    }

    var loadingContent: some View {
        VStack {
            Wrap(UIActivityIndicatorView()) {
                $0.startAnimating()
                $0.color = .systemBlue
            }
            Text("Loading...")
        }
    }

    var loggedOutContent: some View {
        Button(action: { self.viewModel.showSignIn.toggle() })  {
            Text("Sign in")
        }.sheet(isPresented: $viewModel.showSignIn) {
            SignInView(userManager: self.viewModel.userManager, networkModel: self.viewModel.networkModel)
        }
    }

    func loggedInContent<PowerStatusVM: PowerStatusViewModel, PowerHistoryVM: PowerHistoryViewModel>(siteName: String, powerStatusVM: PowerStatusVM, powerHistoryVM: PowerHistoryVM) -> some View {
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
                if isPhone {
                    PowerHistoryView(viewModel: powerHistoryVM)
                        .frame(height: 800)
                } else {
                    PowerHistoryView(viewModel: powerHistoryVM)
                }
            }
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
//        .previewLayout(.fixed(width: 1024, height: 768)) // iPad mini @2x

    }

    final class PreviewHomeViewModel: HomeViewModel {
        typealias State = HomeViewModelState<PowerStatusView_Previews.PreviewPowerStatusViewModel, PowerHistoryView_Previews.PreviewPowerHistoryViewModel>
        var userManager = UserManager()
        var networkModel: TeslaApiProviding = TeslaApi()
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
