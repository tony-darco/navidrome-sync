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
