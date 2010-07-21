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

    static if(is(typeof(garbage) == Brush)) {
        // Having too many brushes active seems to wreak havok on DFL.
        delete garbage;
    }
}

/**The DFL-specific parts of the Figure class.  These include wrappers around
 * the subset of drawing functionality used by Plot2Kill.
 */
class FigureBase : PictureBox {

    mixin(GuiAgnosticBaseMixin);

private:
    // Fudge factors for the space that window borders take up.  TODO:
    // Figure out how to get the actual numbers and use them instead of these
    // stupid fudge factors.
    enum verticalBorderSize = 40;
    enum horizontalBorderSize = 10;

    MemoryGraphics graphics;
    Bitmap bmp;

    // This is indexed via a TextAlignment enum.
    TextFormat[3] textAlignments;

    void resizeEvent(Control c, EventArgs ea) {
        drawPlot();
    }

    // Used only for default plot window.  Resizes this if parent resized.
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
        drawPlot();
    }

protected:
    this() {
        size = Size(800 + verticalBorderSize, 600 + verticalBorderSize);
        resize ~= &resizeEvent;

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
    final void drawLine(Pen pen, int startX, int startY, int endX, int endY) {
        graphics.drawLine(pen,
            startX + xOffset, startY + yOffset,
            endX + xOffset, endY + yOffset);
    }

    final void drawLine(Pen pen, Point start, Point end) {
        this.drawLine(pen, start.x, start.y, end.x, end.y);
    }

    final void drawRectangle(Pen pen, int x, int y, int width, int height) {
        graphics.drawRectangle(pen, x + xOffset, y + yOffset, width, height);
    }

    final void drawRectangle(Pen pen, Rect r) {
        this.drawRectangle(pen, r.x, r.y, r.width, r.height);
    }

    final void fillRectangle(Brush brush, int x, int y, int width, int height) {
        graphics.fillRectangle(brush, x + xOffset, y + yOffset, width, height);
    }

    final void fillRectangle(Brush brush, Rect r) {
        this.fillRectangle(brush, r.x, r.y, r.width, r.height);
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        Rect rect,
        TextAlignment alignment
    ) {
        auto offsetRect = Rect(
            rect.x + xOffset, rect.y + yOffset, rect.width, rect.height);
        graphics.drawText(
            text, font, pointColor, offsetRect, textAlignments[alignment]);
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        Rect rect
    ) {
        auto offsetRect = Rect(
            rect.x + xOffset, rect.y + yOffset, rect.width, rect.height);
        graphics.drawText(text, font, pointColor, offsetRect);
    }

    final Size measureText
    (string text, Font font, int maxWidth, TextAlignment alignment) {
        return
            graphics.measureText(text, font, maxWidth, textAlignments[alignment]);
    }

    final Size measureText
    (string text, Font font, TextAlignment alignment) {
        return
            graphics.measureText(text, font, textAlignments[alignment]);
    }

    final Size measureText(string text, Font font, int maxWidth) {
        return graphics.measureText(text, font, maxWidth);
    }

    final Size measureText(string text, Font font) {
        return graphics.measureText(text, font);
    }

    // TODO:  Add support for stuff other than solid brushes.

    /**Get a brush in a GUI framework-agnostic way.*/
    final Brush getBrush(Color color) {
        return new SolidBrush(color);
    }

    /**Get a pen in a GUI framework-agnostic way.*/
    final Pen getPen(Color color, int width = 1) {
        return new Pen(color, width);
    }


    abstract void drawPlot() {
        this.setBounds(0, 0, width, height);
        graphics = new MemoryGraphics(this.width, this.height);
    }

    final void doneDrawing() {
        bmp = graphics.toBitmap;
        this.image = bmp;
    }

    /**Draws the plots on this Figure.  Useful for attaching to parent.*/
    void drawPlotEvent(Control c, EventArgs ea) {
        drawPlot();
    }

    void drawToRaster(MemoryGraphics graphics) {
        drawToRaster(graphics, this.width, this.height);
    }

    // Weird function overloading bugs.  This should be removed.
    void drawToRaster(MemoryGraphics graphics, int width, int height) {
        return drawToRaster(graphics, Rect(0, 0, width, height));
    }

    // Allows drawing at an offset from the origin.
    void drawToRaster(MemoryGraphics graphics, Rect whereToDraw) {
        // Save the default class-level values, make the values passed in the
        // class-level values, call drawPlot(), then restore the default values.
        auto oldGraphics = this.graphics;
        auto oldWidth = this._width;
        auto oldHeight = this._height;
        auto oldXoffset = this.xOffset;
        auto oldYoffset = this.yOffset;

        scope(exit) {
            this.graphics = oldGraphics;
            this._height = oldHeight;
            this._width = oldWidth;
            this.xOffset = oldXoffset;
            this.yOffset = oldYoffset;
        }

        this.graphics = graphics;
        this._width = whereToDraw.width;
        this._height = whereToDraw.height;
        this.xOffset = whereToDraw.x;
        this.yOffset = whereToDraw.y;
        drawPlot();
    }

    /**Draw and display the figure as a main form.  This is useful in
     * otherwise console-based apps that want to display a few plots.
     * However, you can't have another main form up at the same time.
     */
    void showAsMain() {
        auto f = new Form;
        f.size = Size(this.width + horizontalBorderSize,
                      this.height + verticalBorderSize);
        f.minimumSize = Size(400 + verticalBorderSize, 300 + verticalBorderSize);
        this.parent = f;
        f.activated ~= &drawPlotEvent;
        f.resize ~= &parentResize;
        auto ac = new ApplicationContext;
        ac.mainForm = f;
        Application.run(f);
    }
}

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
