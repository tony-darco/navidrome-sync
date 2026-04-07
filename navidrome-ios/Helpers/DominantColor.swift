import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

extension UIImage {
    /// Extracts the average (dominant) color from the image using CIAreaAverage.
    func dominantColor() -> Color {
        guard let ciImage = CIImage(image: self) else { return .clear }

        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent

        guard let outputImage = filter.outputImage else { return .clear }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}

extension Color {
    /// The app's brand pink color (#FF4E6B).
    static let brandPink = Color(red: 255/255, green: 78/255, blue: 107/255)

    /// The app's brand red color (#FF0436).
    static let brandRed = Color(red: 255/255, green: 4/255, blue: 54/255)

    /// Returns a darker version of the color by blending toward black.
    /// `amount` 0.0 = original color, 1.0 = pure black.
    func darkened(by amount: Double) -> Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let factor = 1.0 - min(max(amount, 0), 1)
        return Color(
            red: Double(r) * factor,
            green: Double(g) * factor,
            blue: Double(b) * factor
        )
    }
}
