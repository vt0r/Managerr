import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color("SplashBackground")
                .ignoresSafeArea()
            Image("SplashImage")
                .accessibilityHidden(true)
        }
    }
}
