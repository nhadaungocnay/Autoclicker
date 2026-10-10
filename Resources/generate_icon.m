#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int sizes[] = {16, 32, 64, 128, 256, 512, 1024};
        int numSizes = sizeof(sizes) / sizeof(sizes[0]);
        NSString *iconsetDir = @"Resources/AppIcon.iconset";
        
        [[NSFileManager defaultManager] createDirectoryAtPath:iconsetDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        for (int i = 0; i < numSizes; i++) {
            int size = sizes[i];
            NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
            [image lockFocus];
            
            NSRect rect = NSMakeRect(0, 0, size, size);
            CGFloat radius = size * 0.22;
            NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, size * 0.05, size * 0.05) xRadius:radius yRadius:radius];
            
            NSGradient *grad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithRed:0.08 green:0.52 blue:0.95 alpha:1.0]
                                                             endingColor:[NSColor colorWithRed:0.35 green:0.12 blue:0.85 alpha:1.0]];
            [grad drawInBezierPath:bgPath angle:-45];
            
            [[NSColor colorWithWhite:1.0 alpha:0.25] setStroke];
            bgPath.lineWidth = MAX(1.0, size * 0.02);
            [bgPath stroke];
            
            NSPoint center = NSMakePoint(size * 0.5, size * 0.5);
            CGFloat scale = (CGFloat)size / 100.0;
            
            // Concentric rings
            for (int ring = 1; ring <= 2; ring++) {
                CGFloat ringRadius = ring * 16.0 * scale;
                NSBezierPath *ringPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - ringRadius, center.y - ringRadius, ringRadius * 2, ringRadius * 2)];
                [[NSColor colorWithWhite:1.0 alpha:0.3 / (CGFloat)ring] setStroke];
                ringPath.lineWidth = 3.0 * scale;
                [ringPath stroke];
            }
            
            // Sleek Mouse Pointer
            NSBezierPath *cursorPath = [NSBezierPath bezierPath];
            [cursorPath moveToPoint:NSMakePoint(center.x - 18 * scale, center.y + 26 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x + 18 * scale, center.y - 4 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x + 4 * scale, center.y - 4 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x + 12 * scale, center.y - 24 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x + 3 * scale, center.y - 27 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x - 5 * scale, center.y - 7 * scale)];
            [cursorPath lineToPoint:NSMakePoint(center.x - 18 * scale, center.y - 7 * scale)];
            [cursorPath closePath];
            
            NSShadow *shadow = [[NSShadow alloc] init];
            shadow.shadowColor = [[NSColor blackColor] colorWithAlphaComponent:0.4];
            shadow.shadowOffset = NSMakeSize(0, -2.0 * scale);
            shadow.shadowBlurRadius = 4.0 * scale;
            [shadow set];
            
            [[NSColor whiteColor] setFill];
            [cursorPath fill];
            
            [image unlockFocus];
            
            NSData *tiffData = [image TIFFRepresentation];
            NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
            NSData *pngData = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            
            NSString *filename1x = (size == 1024) ? @"icon_512x512@2x.png" : [NSString stringWithFormat:@"icon_%dx%d.png", size, size];
            [pngData writeToFile:[NSString stringWithFormat:@"%@/%@", iconsetDir, filename1x] atomically:YES];
            
            if (size <= 512 && (size % 2 == 0)) {
                int half = size / 2;
                if (half >= 16) {
                    NSString *filename2x = [NSString stringWithFormat:@"icon_%dx%d@2x.png", half, half];
                    [pngData writeToFile:[NSString stringWithFormat:@"%@/%@", iconsetDir, filename2x] atomically:YES];
                }
            }
        }
        
        NSLog(@"AppIcon iconset generated successfully.");
    }
    return 0;
}
