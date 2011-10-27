/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */


/**
 * /!\ Unstable api
 *
 * PopOver widget. It is a Dialog you can attach to a widget, e.g. a button.
 *
 * It is a dialog you can attach to a widget, to make it look
 * more consistent, and easier to understand. e.g. if you need to make a popup
 * after clicking on a button as "Create a new document" to choose the type
 * of the document, a popover is more adapted because you can see which button
 * is related to the button, etc... It is also less agressive than a usual
 * dialog because it doesn't hide a big part of the screen. And it is closed
 * when it lose focus.
 *
 * {{images/popover.png}}
 *
 **/

public class Granite.Widgets.PopOver : Gtk.Dialog
{
    protected int BORDER_RADIUS;
    protected int BORDER_WIDTH;
    protected int SHADOW_SIZE;
    protected int ARROW_HEIGHT;
    protected int ARROW_WIDTH;
    protected Gtk.Border PADDINGS;
    double offset = 15.0;
    const int MARGIN = 12;
    Gtk.Widget menu;
    Gtk.CssProvider style_provider;
    Gtk.Box hbox;
    Gtk.Box abox;

    public enum PopPosition
    {
        TOPLEFT,
        TOPRIGHT,
        BOTTOMLEFT,
        BOTTOMRIGHT
    }

    PopPosition pos = PopPosition.TOPRIGHT;
    protected bool arrow_up = false;
    protected double arrow_offset = 35.0;
    static construct {
        
        install_style_property (new GLib.ParamSpecInt ("border-radius",
                                                       "Border radius",
                                                       "Border radius of the popover",
                                                       0, 50, 8,
                                                       ParamFlags.READABLE));
                                                       
        install_style_property (new GLib.ParamSpecInt ("border-width",
                                                       "Border width",
                                                       "Width of the popover's outer border",
                                                       0, 8, 1,
                                                       ParamFlags.READABLE));
        
        install_style_property (new GLib.ParamSpecInt ("shadow-size",
                                                       "Shadow size",
                                                       "Size of the popover's shadow",
                                                       4, 50, 20,
                                                       ParamFlags.READABLE));
        
        install_style_property (new GLib.ParamSpecInt ("arrow-height",
                                                       "Arrow height",
                                                       "Height of the popover's arrow",
                                                       0, 50, 14,
                                                       ParamFlags.READABLE));
        
        install_style_property (new GLib.ParamSpecInt ("arrow-width",
                                                       "Arrow width",
                                                       "Width of the popover's arrow",
                                                       0, 50, 30,
                                                       ParamFlags.READABLE));
    }    
    construct {
        
        // Set up css provider
        style_provider = new Gtk.CssProvider ();
        try {
            style_provider.load_from_path (Build.RESOURCES_DIR + "/style/CompositedWindow.css");
        } catch (Error e) {
            warning ("Could not add css provider. Some widgets will not look as intended. %s", e.message);
        }
        
        // Window properties
        set_visual (get_screen ().get_rgba_visual());
        get_style_context ().add_provider (style_provider, 600);
        app_paintable = true;
        decorated = false;
        resizable = false;
        set_position(Gtk.WindowPosition.NONE);
        set_type_hint(Gdk.WindowTypeHint.NORMAL);
        skip_pager_hint = true;
        skip_pager_hint = true;
    }

    /**
     * Create a new PopOver
     **/
    public PopOver()
    {
        hbox = get_content_area() as Gtk.Box;
        abox = get_action_area() as Gtk.Box;
        menu = new Gtk.Window();
        get_style_context ().add_class ("popover");
        style_get ("border-radius", out BORDER_RADIUS, "border-width", out BORDER_WIDTH,
                   "shadow-size", out SHADOW_SIZE, "arrow-height", out ARROW_HEIGHT,
                   "arrow_width", out ARROW_WIDTH, null);
        PADDINGS = get_style_context ().get_margin (Gtk.StateFlags.NORMAL);
        hbox.set_margin_top(PADDINGS.top + ARROW_HEIGHT + SHADOW_SIZE + 5);
        hbox.set_margin_left(PADDINGS.left + SHADOW_SIZE + 5);
        hbox.set_margin_right(PADDINGS.right + SHADOW_SIZE + 5);
        abox.set_margin_left(PADDINGS.left + SHADOW_SIZE + 5);
        abox.set_margin_right(PADDINGS.right + SHADOW_SIZE + 5);
        abox.set_margin_bottom(PADDINGS.bottom + SHADOW_SIZE + 5);
        
        menu.get_style_context().add_class("popover_bg");

        size_allocate.connect(on_size_allocate);

        focus_out_event.connect_after((f) =>
        {
            foreach(Gtk.Window window in Gtk.Window.list_toplevels())
            {
                if(((int)window.type_hint) != 0 && window.visible)
                {
                    return false;
                }
            }
            hide ();

            return false;
        });
        
        hide.connect( () => { response(Gtk.ResponseType.CANCEL); });
    }

    protected Granite.Drawing.BufferSurface main_buffer;
    
    protected void reset_buffers () {
        
        main_buffer = null;
    }

    /**
     * Set the parent window of the popover. It should not be needed, but it
     * could solve some bugs on some window manager.
     **/
    public void set_parent_pop (Gtk.Window win)
    {
        set_transient_for(win);
        win.configure_event.connect( () => { hide(); return true; });
    }

    void compute_pop_position(Gdk.Screen screen, Gdk.Rectangle rect)
    {
        Gdk.Rectangle monitor_geo;
        screen.get_monitor_geometry (screen.get_monitor_at_point (rect.x, rect.y), out monitor_geo);

        if(rect.x > monitor_geo.x + monitor_geo.width/2)
        {
            /* left */
            if(rect.y < monitor_geo.y + monitor_geo.height/2)
            {
                pos = PopPosition.TOPRIGHT;
            }
            else
            {
                pos = PopPosition.BOTTOMRIGHT;
            }
        }
        else
        {
            if(rect.y < monitor_geo.y + monitor_geo.height/2)
            {
                pos = PopPosition.TOPLEFT;
            }
            else
            {
                pos = PopPosition.BOTTOMLEFT;
            }
        }


        switch(pos)
        {
            case PopPosition.BOTTOMRIGHT:
                arrow_up = false;
                win_x = rect.x - get_allocated_width() + 2*SHADOW_SIZE + ARROW_WIDTH/2 + rect.width / 2;
                win_y = rect.y  - get_allocated_height() + SHADOW_SIZE;
                arrow_offset = get_allocated_width() - 2*SHADOW_SIZE - 30.0;
                break;
            case PopPosition.TOPRIGHT:
                arrow_up = true;
                win_x = rect.x - get_allocated_width() + 2*SHADOW_SIZE + ARROW_WIDTH/2 + rect.width / 2;
                win_y = rect.y - SHADOW_SIZE + rect.height;
                arrow_offset = get_allocated_width() -  2*SHADOW_SIZE - 30.0;
                break;
            case PopPosition.TOPLEFT:
                arrow_up = true;
                win_x = rect.x - 30 - SHADOW_SIZE - ARROW_WIDTH/2 + rect.width / 2;
                win_y = rect.y - SHADOW_SIZE + rect.height;
                arrow_offset = SHADOW_SIZE + 30.0;
                break;
            case PopPosition.BOTTOMLEFT:
                arrow_up = false;
                win_x = rect.x - 30 - SHADOW_SIZE - ARROW_WIDTH/2 + rect.width / 2;
                win_y = rect.y  - get_allocated_height() + SHADOW_SIZE;
                arrow_offset = SHADOW_SIZE + 30.0;
                break;
            default:
                break;
        }
        if (arrow_up) {
            hbox.set_margin_top(PADDINGS.top + SHADOW_SIZE + ARROW_HEIGHT + 5);
            abox.set_margin_bottom(PADDINGS.bottom + SHADOW_SIZE);
        } else {
            hbox.set_margin_top(PADDINGS.top + SHADOW_SIZE + 5);
            abox.set_margin_bottom(PADDINGS.bottom + SHADOW_SIZE + ARROW_HEIGHT);
        }
    }
    int win_x;
    int win_y;

    /**
     * Change the position of the popover, to display it under w.
     *
     * The arrow of the PopOver is moved at the bottom of the widget, and it is
     * horizontally centered.
     *
     * @param w a normal Gtk.Widget, e.g. a button
     **/
    public void move_to_widget (Gtk.Widget w)
    {
        int x, y;
        Gdk.Rectangle rectangle = Gdk.Rectangle();
        w.get_window ().get_origin(out x, out y);
        Gtk.Allocation alloc;
        w.get_allocation (out alloc);
        x += alloc.x;
        y += alloc.y;
        rectangle.x = x;
        rectangle.y = y;
        rectangle.width = alloc.width;
        rectangle.height = alloc.height;
        show_all();
        compute_pop_position (w.get_screen (), rectangle);
        move(win_x, win_y);
        set_parent_pop(w.get_toplevel() as Gtk.Window);
    }

    public void move_to_coords (int x, int y)
    {
        //x -= (int) offset + SHADOW_SIZE + ARROW_WIDTH/2;
        //y -= SHADOW_SIZE;

        show_all();
        Gdk.Rectangle rect = Gdk.Rectangle ();
        rect.x = x;
        rect.y = y;
        rect.width = 1;
        rect.height = 1;

        compute_pop_position (get_screen (), rect);
        move(win_x, win_y);
    }

    /**
    * Move the popover to the coordinates of the given Gdk.Rectangle and
    * position it acording to the width and height of the rectangle.
    **/
    public void move_to_rect (Gdk.Rectangle rect)
    {
        show_all();
        compute_pop_position (get_screen (), rect);
        move(win_x, win_y);
    }

    /**
     * Move the popover to the Gdk.Window window. The recommand method is
     * move_to_widget, but this one can be used when we don't know which widget
     * triggered the action (e.g. with a Gtk.Action).
     **/
    public void move_to_window(Gdk.Window window)
    {
        int x,y,w,h;
        window.get_root_origin(out x, out y);
        window.get_origin(out x, out y);
        x += window.get_width()/2 - MARGIN - SHADOW_SIZE - (int)offset;
        y += window.get_height() - SHADOW_SIZE;
        show_all();
        show_now();
        move(x, y);
    }

    protected void cairo_popover (Cairo.Context cr, double x, double y, double width, double height) {
    
        // Start with rounded rectangle as base
        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, (arrow_up) ? y + ARROW_HEIGHT : y,
                                                           width, height - ARROW_HEIGHT, BORDER_RADIUS);
        
        // Draw arrow
        if (arrow_up) {
            cr.move_to (arrow_offset, y + ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
        } else {
            cr.move_to (arrow_offset, y + height - ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
        }
        cr.close_path ();  
    }

    void on_size_allocate(Gtk.Allocation alloc)
    {
        int w = get_allocated_width();
        int h = get_allocated_height();
        reset_buffers ();
        main_buffer = new Granite.Drawing.BufferSurface (w, h);
        
        // Shadow first
        cairo_popover (main_buffer.context, SHADOW_SIZE + BORDER_WIDTH / 2.0, SHADOW_SIZE + BORDER_WIDTH / 2.0,
                       w - SHADOW_SIZE * 2 - BORDER_WIDTH, h - SHADOW_SIZE * 2 - BORDER_WIDTH);
        main_buffer.context.set_source_rgba (0.0, 0.0, 0.0, 0.4);
        main_buffer.context.fill_preserve ();
        main_buffer.exponential_blur (SHADOW_SIZE / 2 - 1); // rough approximation 
        
        // Outer border
        main_buffer.context.set_operator (Cairo.Operator.SOURCE);
        main_buffer.context.set_line_width (BORDER_WIDTH);
        Gdk.cairo_set_source_rgba (main_buffer.context, get_style_context ().get_border_color (Gtk.StateFlags.NORMAL));
        main_buffer.context.stroke_preserve ();
        
        // Background        
        main_buffer.context.clip ();
        Gtk.render_background (menu.get_style_context (), main_buffer.context, SHADOW_SIZE, SHADOW_SIZE, w - 2 * SHADOW_SIZE, h - 2 * SHADOW_SIZE);

        /*if (arrow_up) {
            margin_top = PADDINGS.top + SHADOW_SIZE + ARROW_HEIGHT;
            margin_bottom = PADDINGS.bottom + SHADOW_SIZE;
        } else {
            margin_top = PADDINGS.top + SHADOW_SIZE;
            margin_bottom = PADDINGS.bottom + SHADOW_SIZE + ARROW_HEIGHT;
        }*/
    }

    public override bool draw(Cairo.Context cr)
    {
/*        cr.set_source_rgba(0,0,0, 0.5);
        cr.paint();
  */      cr.set_source_surface(main_buffer.surface, 0, 0);
        cr.paint_with_alpha(1.0);
        return base.draw(cr);
    }
}