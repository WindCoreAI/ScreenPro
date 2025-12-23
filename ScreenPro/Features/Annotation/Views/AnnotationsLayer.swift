import SwiftUI
import CoreGraphics

// MARK: - AnnotationsLayer (T010)

/// A view that renders all annotations using Core Graphics.
/// This layer is overlaid on top of the base image.
struct AnnotationsLayer: View {
    @ObservedObject var document: AnnotationDocument
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            // Sort annotations by z-index for proper layering
            let sortedAnnotations = document.annotations.sorted { $0.zIndex < $1.zIndex }

            // Render each annotation
            context.withCGContext { cgContext in
                // Apply scale transform
                cgContext.scaleBy(x: scale, y: scale)

                for annotation in sortedAnnotations {
                    annotation.render(in: cgContext, scale: scale)
                }
            }
        }
        .allowsHitTesting(false) // Pass through hits to canvas view
    }
}

// MARK: - Preview

#if DEBUG
struct AnnotationsLayer_Previews: PreviewProvider {
    static var previews: some View {
        // Create a test image
        let testImage = createTestImage()

        // Create a document with test annotations
        let document = AnnotationDocument(image: testImage)

        // Add test annotations
        let rect1 = PlaceholderAnnotation(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            color: .red,
            strokeWidth: 3
        )
        let rect2 = PlaceholderAnnotation(
            bounds: CGRect(x: 150, y: 100, width: 80, height: 60),
            color: .blue,
            strokeWidth: 2
        )

        document.addAnnotation(rect1)
        document.addAnnotation(rect2)

        return AnnotationsLayer(document: document, scale: 1.0)
            .frame(width: 400, height: 300)
            .background(Color.gray.opacity(0.2))
    }

    static func createTestImage() -> CGImage {
        let width = 400
        let height = 300

        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Fill with white
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }
}
#endif
