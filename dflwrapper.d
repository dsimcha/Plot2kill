/**This file contains the DFL-specific parts of Plot2Kill and is publicly
 * imported by plot2kill.figure if compiled with -version=dfl.
 *
 * Note that since DFL was the first library that Plot2Kill was ported to,
 * it is considered the native lib and most stuff in this module maps cleanly
 * and directly to DFL.
 *
 * BUGS:
 *
 * 1. Rotated text for Y-Axis labels isn't available in DFL.  Therefore,
 *    Y-Axis labels are rendered in ugly columnar text.
 *
 * 2. There is currently no "proper" way to save a plot.  This is because
 *    DFL's Bitmap object doesn't provide a way to obtain the underlying
 *    pixels yet, and core.stdc.windows doesn't seem to provide the necessary
 *    stuff to do it manually via the Windows API.  In the meantime, a
 *    workaround (at least for manual, as opposed to programmatic, saving)
 *    is to take a screenshot using the print screen key and save
 *    this.
 */
module plot2kill.dflwrapper;


version(dfl) {

import dfl.all;

import plot2kill.util;
import plot2kill.guiagnosticbase;

/**DFL's implementation of a color object.*/
alias dfl.drawing.Color Color;

/**DFL's implementation of a line drawing object.*/
alias dfl.drawing.Pen Pen;

/**DFL's implementation of a filled area drawing object.*/
alias dfl.drawing.Brush Brush;

/**DFL's object for representing a point.*/
alias dfl.drawing.Point Point;

/**DFL's implementation of a rectangle object.*/
alias dfl.drawing.Rect Rect;

/**DFL's size object.*/
alias dfl.drawing.Size Size;

/**DFL's font class.*/
alias dfl.drawing.Font Font;

/**Get a color in a GUI framework-agnostic way.*/
Color getColor(ubyte red, ubyte green, ubyte blue) {
    return Color(red, green, blue);
}

/**Get a font in a GUI framework-agnostic way.*/
Font getFont(string fontName, int size) {
    return new Font(fontName, size);
}

///
enum TextAlignment {
    ///
    Left = 0,

    ///
    Center = 1,

    ///
    Right = 2
}

// This calls the relevant lib's method of cleaning up the given object, if
// any.
void doneWith(T)(T garbage) {
    static if(is(typeof(garbage.dispose()))) {
        garbage.dispose();
    }

    static if(is(T : Brush) || is(T : Pen)) {
        // Having too many brushes and pens active seems to wreak havok on DFL.
        delete garbage;
    }
}

/**The DFL-specific parts of the Figure class.  These include wrappers around
 * the subset of drawing functionality used by Plot2Kill.
 */
class FigureBase : GuiAgnosticBase {
private:
    // This is indexed via a TextAlignment enum.
    TextFormat[3] textAlignments;

    Rect roundedRect(double x, double y, double width, double height) {
        // This code is designed to make sure the right/bottom of the rectangle
        // always ends up as close as possible to where it was intended to,
        // even if rounding fscks up the x/y coordinate, and to favor making
        // the rectangle too big instead of too small since too big looks
        // less bad.

        // Round down to make rectangle wider than it should be since overshoot
        // is less severe aesthetically than undershoot.
        immutable intX = to!int(x);
        immutable intY = to!int(y);

        immutable endX = x + width;
        immutable endY = y + height;

        // Since overshoot looks better than undershoot, we want the minimum
        // value of width and height that will not give undershoot.
        immutable intWidth = to!int(ceil(endX - intX));
        immutable intHeight = to!int(ceil(endY - intY));

        return Rect(intX, intY, intWidth, intHeight);
    }

protected:
    // Fonts tend to be different actual sizes on different GUI libs for a
    // given nominal size. This adjusts for that factor when setting default
    // fonts.
    enum fontSizeAdjust = -3;

    Graphics context;

    this() {
        textAlignments[TextAlignment.Left] = new TextFormat;
        textAlignments[TextAlignment.Left].alignment
            = dfl.drawing.TextAlignment.LEFT;

        textAlignments[TextAlignment.Center] = new TextFormat;
        textAlignments[TextAlignment.Center].alignment
            = dfl.drawing.TextAlignment.CENTER;

        textAlignments[TextAlignment.Right] = new TextFormat;
        textAlignments[TextAlignment.Right].alignment
            = dfl.drawing.TextAlignment.RIGHT;
    }


public:

    // Wrappers around DFL's drawing functionality.  Other ports should have
    // wrappers with the same compile-time interface.  These are final both
    // to avoid virtual call overhead and because overriding them would be
    // rather silly.
    final void drawLine
    (Pen pen, double startX, double startY, double endX, double endY) {
        context.drawLine(pen,
            roundTo!int(startX + xOffset), roundTo!int(startY + yOffset),
            roundTo!int(endX + xOffset), roundTo!int(endY + yOffset)
        );
    }

    final void drawLine(Pen pen, PlotPoint start, PlotPoint end) {
        this.drawLine(pen, start.x, start.y, end.x, end.y);
    }

    final void drawRectangle
    (Pen pen, double x, double y, double width, double height) {
        auto r = roundedRect(x + xOffset, y + yOffset, width, height);
        context.drawRectangle
            (pen, r.x , r.y , r.width, r.height);
    }

    final void drawRectangle(Pen pen, PlotRect r) {
        this.drawRectangle(pen, r.x, r.y, r.width, r.height);
    }

    final void fillRectangle
    (Brush brush, double x, double y, double width, double height) {
        auto r = roundedRect(x + xOffset, y + yOffset, width, height);
        context.fillRectangle
            (brush, r.x, r.y, r.width, r.height);
    }

    final void fillRectangle(Brush brush, PlotRect r) {
        this.fillRectangle(brush, r.x, r.y, r.width, r.height);
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect,
        TextAlignment alignment
    ) {
        auto offsetRect = Rect(
            roundTo!int(rect.x + xOffset),
            roundTo!int(rect.y + yOffset),
            roundTo!int(rect.width),
            roundTo!int(rect.height)
        );
        context.drawText(
            text, font, pointColor, offsetRect, textAlignments[alignment]);
    }

    // BUGS:  Draws columnar text, not rotated text, unless you're running DFL
    // with patches that I haven't released yet.  Also, in the columnar text
    // case, since it's such a kludge anyhow, assumes you really want the text
    // centered w.r.t. the whole figure.
    final void drawRotatedText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect,
        TextAlignment alignment
    ) {
        static if(is(dfl.drawing.RFont)) {  // Patched DFL
            auto rfont = new RFont(font.name, font.size);
            scope(exit) doneWith(rfont);

            auto meas = measureText(text, font);
            auto slack = max(0, rect.height - meas.width);
            double toAdd;
            if(alignment == TextAlignment.Center) {
                toAdd = slack / 2;
            } else if(alignment == TextAlignment.Right) {
                toAdd = slack;
            }

            // The rotated text patch is buggy, and will try to wrap words
            // when it shouldn't.  Make width huge to effectively disable
            // wrapping.  Also, DFL's Y coord is for the bottom, not the top.
            // Fix this.
            auto rect2 = PlotRect(
                rect.x, rect.y + meas.width + toAdd,
                10 * this.width, rect.width);
            drawText(text, rfont, getColor(0, 0, 0), rect2);
        } else {
            // Render butt-ugly columnar text and assume it should be
            // centered vertically w.r.t. the figure as a whole.
            text = addNewLines(text);
            auto meas = measureText(text, font);
            auto slack = max(0, this.height - meas.height);

            auto rect2 = PlotRect(rect.x, slack / 2, meas.width, meas.height);
            drawText(text, font, pointColor, rect2);
        }
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect
    ) {
        auto offsetRect = Rect(
            roundTo!int(rect.x + xOffset),
            roundTo!int(rect.y + yOffset),
            roundTo!int(rect.width), roundTo!int(rect.height)
        );
        context.drawText(text, font, pointColor, offsetRect);
    }

    final Size measureText
    (string text, Font font, double maxWidth, TextAlignment alignment) {
        return context.measureText(text, font, roundTo!int(maxWidth),
            textAlignments[alignment]);
    }

    final Size measureText
    (string text, Font font, TextAlignment alignment) {
        return
            context.measureText(text, font, textAlignments[alignment]);
    }

    final Size measureText(string text, Font font, double maxWidth) {
        return context.measureText(text, font, roundTo!int(maxWidth));
    }

    final Size measureText(string text, Font font) {
        return context.measureText(text, font);
    }

    // TODO:  Add support for stuff other than solid brushes.

    /**Get a brush in a GUI framework-agnostic way.*/
    final Brush getBrush(Color color) {
        return new SolidBrush(color);
    }

    /**Get a pen in a GUI framework-agnostic way.*/
    final Pen getPen(Color color, double width = 1) {
        return new Pen(color, max(roundTo!int(width), 1));
    }

    void drawTo(Graphics context) {
        drawTo(context, this.width, this.height);
    }

    // Weird function overloading bugs.  This should be removed.
    void drawTo(Graphics context, double width, double height) {
        return drawTo(context, PlotRect(0, 0, width, height));
    }

    // Allows drawing at an offset from the origin.
    void drawTo(Graphics context, PlotRect whereToDraw) {
        enforceSane(whereToDraw);
        // Save the default class-level values, make the values passed in the
        // class-level values, call draw(), then restore the default values.
        auto oldContext = this.context;
        auto oldWidth = this._width;
        auto oldHeight = this._height;
        auto oldXoffset = this.xOffset;
        auto oldYoffset = this.yOffset;

        scope(exit) {
            this.context = oldContext;
            this._height = oldHeight;
            this._width = oldWidth;
            this.xOffset = oldXoffset;
            this.yOffset = oldYoffset;
        }

        this.context = context;
        this._width = whereToDraw.width;
        this._height = whereToDraw.height;
        this.xOffset = whereToDraw.x;
        this.yOffset = whereToDraw.y;
        drawImpl();
    }

    /**Save this figure to a file.  Currently, the only format supported is
     * .bmp.  When this situation improves, the extension of the file will
     * be used to determine what format to use.  The width and height parameters
     * allow you to specify explicit width and height parameters for the image
     * file.  If width and height are left at their default values
     * of 0, the default width and height of the subclass being saved will
     * be used.
     *
     * Note:  The width and height parameters are provided as doubles for
     *        consistency with backends that support vector formats.  These
     *        are simply rounded to the nearest integer for the DFL backend.
     */
    void saveToFile(string filename, double width = 0, double height = 0) {
        enforce(width >= 0 && height >= 0);

        if(width == 0 || height == 0) {
            width = this.defaultWindowWidth;
            height = this.defaultWindowHeight;
        }

        immutable iWidth = roundTo!int(width);
        immutable iHeight = roundTo!int(height);

        auto graphics = new MemoryGraphics(iWidth, iHeight);
        scope(exit) doneWith(graphics);

        this.drawTo(graphics, iWidth, iHeight);
        File handle = File(filename, "wb");
        scope(exit) handle.close();

        auto pix = getPixels(graphics);
        scope(exit) GC.free(cast(void*) pix.ptr);

        writeBitmap(pix, handle, iWidth, iHeight);
    }

    ///
    FigureControl toControl() {
        return new FigureControl(this);
    }

    ///
    void showAsMain() {
        Application.run(new DefaultPlotWindow(this.toControl));
    }
}

// Fudge factors for the space that window borders take up.
//
// TODO:
// Figure out how to get the actual numbers and use them instead of these
// stupid fudge factors, though I couldn't find any API in DFL to do that.
private enum verticalBorderSize = 38;
private enum horizontalBorderSize = 16;

class FigureControl : PictureBox {
private:
    FigureBase _figure;

package:
    this(FigureBase fig) {
        this._figure = fig;
        this.size = Size(fig.minWindowWidth, fig.minWindowHeight);
    }

    void parentResize(Control c, EventArgs ea) {


        immutable pwid = parent.width - horizontalBorderSize;
        immutable pheight = parent.height - verticalBorderSize;

        // Skip redraw if difference is negligible.  This speeds things up
        // a lot.
        if(abs(pwid - width) < 5 && abs(height - pheight) < 5) {
            return;
        }

        this.size = Size(parent.width - horizontalBorderSize,
                         parent.height - verticalBorderSize);

        draw();
    }

public:
    /// Event handler to redraw the figure.
    void drawFigureEvent(Control c, EventArgs ea) {
        draw();
    }

    /**Get the underlying FigureBase object.*/
    final FigureBase figure() @property {
        return _figure;
    }

    ///
    void draw() {
        this.setBounds(0, 0, this.width, this.height);
        auto context = new MemoryGraphics(this.width, this.height);

        figure.drawTo(context, this.width, this.height);
        auto bmp = context.toBitmap;
        this.image = bmp;
    }
}

///
class DefaultPlotWindow : Form {
private:
    FigureControl control;
    enum string fileFilter = "BMP files (*.bmp)|*.bmp";

    // Brings up a save menu when the window is right clicked on.
    void rightClickSave(Control c, MouseEventArgs ea) {
        if(ea.button != MouseButtons.RIGHT) {
            return;
        }

        auto dialog = new SaveFileDialog;
        dialog.overwritePrompt = true;
        dialog.filter = fileFilter;
        dialog.validateNames = true;
        dialog.showDialog(this);

        // For now the only choice is bmp.  Eventually we hope to support png.
        if(dialog.fileName.length == 0) {
            // User hit cancel.
            return;
        }

        control.figure.saveToFile(
            dialog.fileName,
            control.width,
            control.height
        );
    }

public:
    ///
    this(FigureControl control) {
        control.dock = DockStyle.FILL;
        this.control = control;
        control.size = Size(
            control.figure.defaultWindowWidth,
            control.figure.defaultWindowHeight
        );

        this.size = Size(
            control.width + horizontalBorderSize,
            control.height + verticalBorderSize
        );
        this.minimumSize =
            Size(control.figure.minWindowWidth + horizontalBorderSize,
                 control.figure.minWindowHeight + verticalBorderSize);

        this.resize ~= &control.parentResize;
        this.activated ~= &control.drawFigureEvent;
        control.mouseDown ~= &rightClickSave;
        control.parent = this;
        control.bringToFront();
    }
}

private:
// This stuff is an attempt at providing support for saving DFL plots to
// bitmaps.  It borrows from Tomasz Stachowiak's excellent DirectBitmap code,
// which was licensed under the also excellent WTFPL.

import dfl.internal.winapi;
import std.c.stdlib : malloc, free;

// Get the bitmap as an array of pixels.
Pixel[] getPixels(MemoryGraphics graphics) {
    // Calculate bitmap padding.  Bitmaps require the number of bytes per line
    // to be divisible by 4.
    int paddingBytes;
    while((paddingBytes + graphics.width * 3) % 4 > 0) {
        paddingBytes++;
    }
    auto pixels = new byte[graphics.height * (graphics.width * 3 + paddingBytes)];

	BITMAPINFO	bitmapInfo;
    with (bitmapInfo.bmiHeader) {
        biSize = bitmapInfo.bmiHeader.sizeof;
        biWidth = graphics.width;
        biHeight = graphics.height;
        biPlanes = 1;
        biBitCount = 24;
        biCompression = BI_RGB;
    }

    int result = GetDIBits(
        graphics.handle,
        graphics.hbitmap,
        0,
        graphics.height,
        pixels.ptr,
        &bitmapInfo,
        DIB_RGB_COLORS
    );

    enforce(result == graphics.height, "Reading bitmap pixels failed.");

    if(paddingBytes > 0) {
        // Remove padding bits.
        size_t toIndex, fromIndex;
        foreach(row; 0..graphics.height) {
            foreach(i; 0..graphics.width * 3) {
                pixels[toIndex++] = pixels[fromIndex++];
            }

            fromIndex += paddingBytes;
        }
    }

    return (cast(Pixel*) pixels.ptr)[0..graphics.width * graphics.height];
}

extern(Windows) int GetDIBits(
  HDC hdc,           // handle to DC
  HBITMAP hbmp,      // handle to bitmap
  UINT uStartScan,   // first scan line to set
  UINT cScanLines,   // number of scan lines to copy
  LPVOID lpvBits,    // array for bitmap bits
  LPBITMAPINFO lpbi, // bitmap data buffer
  UINT uUsage        // RGB or palette index
);


enum UINT DIB_RGB_COLORS = 0;
enum UINT BI_RGB = 0;

struct Pixel {
	align(1) {
		ubyte b, g, r;
	}
}
static assert (Pixel.sizeof == 3);


// Bugs:  Doesn't work at all.  I have no idea why.
version(none) {
/* This class contains an implementation of an ad-hoc message passing
 * system that allows plots to be thrown up from any thread w/o
 * an explicit main GUI window.  This is useful for apps that are
 * basically console apps except for the plots they display.
 */
private class ImplicitMain {

    __gshared static {
        Form implicitMain;
        Button implicitButton;
        Form[] toShow;

        void initialize() {
            synchronized(ImplicitMain.classinfo) {
                if(implicitMain !is null) {
                    return;
                }

                implicitMain = new Form;
               // implicitMain.visible = false;

                implicitButton = new Button;
                implicitButton.click ~= toDelegate(&showToShow);
                implicitButton.parent = implicitMain;
            }

            static void doIt() {
                auto ac = new ApplicationContext;
                ac.mainForm = implicitMain;
                Application.run(ac);
            }

           auto t = new Thread(&doIt);
           t.isDaemon = true;
           t.start;
           doIt;
        }

        void showToShow(Control c, EventArgs ea) {
            synchronized(ImplicitMain.classinfo) {
                while(!toShow.empty) {
                    toShow.back().show();
                    toShow.popBack();
                }
            }
        }

        void addForm(Form form) {
            synchronized(ImplicitMain.classinfo) {
                toShow ~= form;
                implicitButton.performClick();
            }
        }
    }
}
}


}
