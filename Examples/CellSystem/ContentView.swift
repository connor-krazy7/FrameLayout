import FrameLayout
import SwiftUI

struct ContentView: View {
    var body: some View {
        DemoViewController.asViewRepresentable()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
    
//    FLNodePreview(
//        node: FLVStack(
//            alignment: .center,
//            spacing: 8
//        ) {
//            FLColor(.red)
//                .frame(width: 88, height: 44)
//                .clipShape(.capsule)
//                .padding(10)
//                .background(.blue)
//                .clipShape(.roundedRectangle(20))
//                .border(.black, width: 1)
//                .clipShape(.roundedRectangle(10))
//                .padding(40)
//                .border(.black, width: 2)
//                .overlay(
//                    FLText(NSAttributedString(string: "text"))
//                        .frame(
//                            maxWidth: .infinity,
//                            maxHeight: .infinity,
//                            alignment: .top
//                        )
//                )
//
//            FLSpacer()
//
//            FLColor(.brown)
//                .frame(width: 50)
//                .frame(maxHeight: .infinity)
//
//            FLSpacer()
//
//            FLColor(.yellow)
//                .frame(width: 88, height: 44)
//        }.frame(width: 300, height: 300),
//        layoutContext: FLContext(
//            width: 300,
//            height: 300
//        )
//    )
//    .border(.red, width: 4)
//    .padding(20)
//    .background(.gray.opacity(0.3))
}
