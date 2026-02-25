import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        Color("SplashBackground")
            .ignoresSafeArea()
            .overlay {
                Image("SplashImage")
                    .resizable()
                    .scaledToFit()
                    .padding(73)
            }
    }
}
