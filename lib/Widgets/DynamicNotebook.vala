
const string BUTTON_STYLE = """
* {
    -GtkButton-default-border : 0;
    -GtkButton-default-outside-border : 0;
    -GtkButton-inner-border: 0;
    -GtkWidget-focus-line-width : 0;
    -GtkWidget-focus-padding : 0;
    padding: 0;
}
""";

namespace Granite.Widgets {
    
    public class Tab : Gtk.Box {
        Gtk.Label _label;
        public string label {
            get { return _label.label;  }
            set { _label.label = value; }
        }
        internal Gtk.EventBox page_container;
        public Gtk.Widget page {
            get {
            	return page_container.get_child ();
        	}
            set {
            	if (page_container.get_child () != null)
            		page_container.remove (page_container.get_child ());
        		page_container.add (value);
        		page_container.show_all ();
            }
        }
        internal Gtk.Image _icon;
        public GLib.Icon? icon {
            owned get { return _icon.gicon;  }
            set { _icon.gicon = value; }
        }
        Gtk.Spinner _working;
        bool __working;
        public bool working {
            get { return __working; }
            set { __working = _working.visible = value; _icon.visible = !value; }
        }
        
        public Pango.EllipsizeMode ellipsize_mode {
        	get { return _label.ellipsize; }
        	set { _label.ellipsize = value; }
        }
        
        bool _fixed;
        public bool fixed {
        	get { return _fixed; }
        	set {
        		if (value != _fixed) {
        			_label.visible = value;
        			close.visible = value;
        		}
        		_fixed = value;
        	}
        }
        
        internal Gtk.Button close;
        
        internal signal void closed ();
        
        public Tab (string label="", GLib.Icon? icon=null, Gtk.Widget? page=null) {
            this._label   = new Gtk.Label (label);
            if (icon != null)
            	this._icon = new Gtk.Image.from_gicon (icon, Gtk.IconSize.MENU);
        	else
        		this._icon = new Gtk.Image.from_stock (Gtk.Stock.MISSING_IMAGE, Gtk.IconSize.MENU);
            this._working = new Gtk.Spinner ();
            this.close    = new Gtk.Button ();
            
            working = false;
            
            close.add (new Gtk.Image.from_stock (Gtk.Stock.CLOSE, Gtk.IconSize.MENU));
            close.tooltip_text = _("Close tab");
            close.relief = Gtk.ReliefStyle.NONE;
            
            var lbl = new Gtk.EventBox ();
            _label.set_tooltip_text (label);
            lbl.add (_label);
            _label.ellipsize = Pango.EllipsizeMode.END;
            lbl.visible_window = false;
            
            this.pack_start (this.close, false);
            this.pack_start (lbl);
            this.pack_start (this._icon, false);
            this.pack_start (this._working, false);
            
            this._working.show.connect (() => {
            	if (!working)
            		_working.hide ();
            });
            
            page_container = new Gtk.EventBox ();
            page_container.add ((page == null)?new Gtk.Label (""):page);
            page_container.show_all ();
            
            this.show_all ();
            
            lbl.button_release_event.connect ( (e) => {
                if (e.button == 2) {
                    this.closed ();
                    return true;
                }
                return false;
            });
            
            close.clicked.connect ( () => this.closed () );
        }
    }
    
    public class DynamicNotebook : Gtk.EventBox {
        
        /**
         * number of pages
         **/
        public int n_tabs {
            get { return notebook.get_n_pages (); }
            private set {}
        }
        
        /**
         * Hide the tab bar and only show the pages
         **/
        public bool show_tabs {
            get { return notebook.show_tabs;  }
            set { notebook.show_tabs = value; }
        }
        
        bool _show_icons;
        /**
         * Toggle icon display
         **/
        public bool show_icons {
        	get { return _show_icons; }
        	set {
        		if (_show_icons != value) {
        			tabs.foreach ((t) => t._icon.visible = value );
        		}
        		_show_icons = value;
    		}
        }
        /**
         * Hide the close buttons and disable closing of tabs
         **/
        bool _tabs_closable = false;
        public bool tabs_closable {
            get { return _tabs_closable; }
            set {
            	if (value != _tabs_closable)
            		tabs.foreach ((t) => {
            			t.close.visible = value;
            		});
            	_tabs_closable = value;
        	}
        }
        /**
         * Make tabs reorderable
         **/
        bool _allow_drag = true;
        public bool allow_drag {
            get { return _allow_drag; }
            set {
                _allow_drag = value;
                this.tabs.foreach ( (t) => {
                    notebook.set_tab_reorderable (t.page_container, value);
                });
            }
        }
        /**
         * Allow creating new windows by dragging a tab out
         **/
        bool _allow_new_window = false;
        public bool allow_new_window {
            get { return _allow_new_window; }
            set {
                _allow_new_window = value;
                this.tabs.foreach ( (t) => {
                    notebook.set_tab_detachable (t.page_container, value);
                });
            }
        }
        
        public Tab current {
        	get { return tabs.nth_data (notebook.get_current_page ()); }
        	set { notebook.set_current_page (tabs.index (value)); }
        }
        
        GLib.List<Tab> _tabs;
        public GLib.List<Tab> tabs {
            get {
                _tabs = new GLib.List<Tab> ();
                for (var i=0;i<n_tabs;i++) {
                    _tabs.append (notebook.get_tab_label (notebook.get_nth_page (i)) as Tab);
                }
                return _tabs;
            }
            private set {}
        }
        
        public string group_name {
        	get { return notebook.group_name; }
        	set { notebook.group_name = value; }
        }
        
        public Gtk.Notebook    notebook;
        private Gtk.CssProvider button_fix;
        
        private int tab_width = 150;
        private int max_tab_width = 150;
        
        public signal void tab_added (Tab tab);
        public signal bool tab_removed (Tab tab);
        Tab? old_tab; //stores a reference for tab_switched
        public signal void tab_switched (Tab? old_tab, Tab new_tab);
        public signal void tab_moved (Tab tab, int new_pos, bool new_window, int x, int y);
        
        /**
         * create a new dynamic notebook
         **/
        public DynamicNotebook () {
            
            this.button_fix = new Gtk.CssProvider ();
            try {
                this.button_fix.load_from_data (BUTTON_STYLE, -1);
            } catch (Error e) { warning (e.message); }
            
            this.notebook = new Gtk.Notebook ();
            this.visible_window = false;
            this.get_style_context ().add_class ("dynamic-notebook");
            
            this.notebook.scrollable = true;
            this.notebook.show_border = false;
            
            this.draw.connect ( (ctx) => {
                this.get_style_context ().render_activity (ctx, 0, 0, this.get_allocated_width (), 27);
                return false;
            });
            
            this.add (this.notebook);
            
            
            var add = new Gtk.Button ();
            add.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU));
            add.margin_left = 6;
            add.relief = Gtk.ReliefStyle.NONE;
            add.tooltip_text = _("New tab");
            this.notebook.set_action_widget (add, Gtk.PackType.START);
            add.show_all ();
            add.get_style_context ().add_provider (button_fix, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            
            add.clicked.connect ( () => {
                 var t = new Tab ();
                 notebook.page = (int)this.insert_tab (t, -1);
                 this.tab_added (t);
            });
            
            this.size_allocate.connect ( () => {
                this.recalc_size ();
            });
            
            this.key_press_event.connect ( (e) => {
                switch (e.keyval){
                    case 119: //ctrl+w
                        if (Signal.has_handler_pending (this, //if no one listens, just kill it!
                            Signal.lookup ("tab-removed", typeof (DynamicNotebook)), 0, true)) {
                            var sure = this.tab_removed (tabs.nth_data (this.notebook.page));
                            if (sure)
                                this.notebook.remove_page (this.notebook.page);
                        } else {
                            this.notebook.remove_page (this.notebook.page);
                        }
                        return true;
                    case 116: //ctrl+t
                        var t = new Tab ();
                        this.tab_added (t);
                        notebook.page = (int)this.insert_tab (t, -1);
                        return true;
                    case 49: //ctrl+[1-8]
                    case 50:
                    case 51:
                    case 52:
                    case 53:
                    case 54:
                    case 55:
                    case 56:
                        if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0){
                            var i = e.keyval - 49;
                            this.notebook.page = (int)((i >= this.notebook.get_n_pages ()) ? 
                                this.notebook.get_n_pages () - 1 : i);
                            return true;
                        }
                        break;
                    /*case 65289: //tab (and shift+tab)    not working :(  (Gtk seems to move focus)
                    case 65056:
                        if ((e.state & Gdk.ModifierType.SHIFT_MASK) != 0){
                            this.prev ();
                            return true;
                        }else if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0){
                            this.next ();
                            return true;
                        }
                        break;*/
                }
                return false;
            });
            
            this.notebook.button_press_event.connect ( (e) => {
                /*if (e.button == 1) {
                    this.get_parent_window ().begin_move_drag ((int)e.button, (int)e.x_root, (int)e.y_root, e.time);
                    return true;
                }*/
                return false;
            });
            
            notebook.switch_page.connect (on_switch_page);
            notebook.page_reordered.connect (on_page_reordered);
            notebook.create_window.connect (on_create_window);
        }
        
        ~Notebook ()
        {
        	notebook.switch_page.disconnect (on_switch_page);
        	notebook.page_reordered.disconnect (on_page_reordered);
        	notebook.create_window.disconnect (on_create_window);
        }
        
        void on_switch_page (Gtk.Widget page, uint pagenum)
        {
        	var new_tab = notebook.get_tab_label (page) as Tab;
        	
        	tab_switched (old_tab, new_tab);
        	old_tab = new_tab;
        }
        
        void on_page_reordered (Gtk.Widget page, uint pagenum)
        {
        	tab_moved (notebook.get_tab_label (page) as Tab, (int)pagenum, false, -1, -1);
        }
        
        weak Gtk.Notebook on_create_window (Gtk.Widget page, int x, int y)
        {
        	tab_moved (notebook.get_tab_label (page) as Tab, 0, true, x, y);
        	return null;
        }
        
        private void recalc_size ()
        {
            if (n_tabs == 0)
                return;
            
            var offset = 130;
            this.tab_width = (this.get_allocated_width () - offset) / this.notebook.get_n_pages ();
            if (this.tab_width > max_tab_width)
                this.tab_width = max_tab_width;
            
            for (var i=0;i<this.notebook.get_n_pages ();i++) {
                this.notebook.get_tab_label (this.notebook.get_nth_page (i)).width_request = tab_width;
            }
        }
        
        public void remove_tab (Tab tab)
        {
        	notebook.remove_page (get_tab_position (tab));
        }
        /*
        private void next ()
        {
            this.notebook.page = (this.notebook.page + 1 >= this.notebook.get_n_pages ())?
                this.notebook.page = 0 : this.notebook.page + 1;
        }
        private void prev () {
            this.notebook.page = (this.notebook.page - 1 < 0)?this.notebook.get_n_pages () - 1:
                this.notebook.page-1;
        }
        */
        
        public override void show ()
        {
        	base.show ();
        	notebook.show ();
        }
        
        public new List<Gtk.Widget> get_children ()
        {
        	var list = new List<Gtk.Widget> ();
        	
        	foreach (var child in notebook.get_children ()) {
        		list.append ((child as Gtk.Container).get_children ().nth_data (0));
        	}
        	return list;
        }
        
        public int get_tab_position (Tab tab)
        {
            return this.notebook.page_num (tab.page_container);
        }
        public void set_tab_position (Tab tab, int position)
        {
        	notebook.reorder_child (tab.page, position);
        }
        
        public Tab? get_tab_by_index (int index) {
        	return notebook.get_tab_label (notebook.get_nth_page (index)) as Tab;
        }
        
        public Tab? get_tab_by_widget (Gtk.Widget widget) {
        	return notebook.get_tab_label (widget) as Tab;
        }
        
        public Gtk.Widget get_nth_page (int index) {
        	return notebook.get_nth_page (index);
        }
        
        public uint insert_tab (Tab tab, int index) {
            
            return_if_fail (tabs.index (tab) < 0);
            
            var i = 0;
            if (index == -1)
            	i = this.notebook.append_page (tab.page_container, tab);
        	else
        		i = this.notebook.insert_page (tab.page_container, tab, index);
            
            this.notebook.set_tab_reorderable (tab.page_container, this.allow_drag);
            this.notebook.set_tab_detachable  (tab.page_container, this.allow_new_window);
            
        	tab._icon.visible = show_icons;
            
            tab.width_request = tab_width;
            tab.close.get_style_context ().add_provider (button_fix, 
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            
            tab.closed.connect ( () => {
                if (Signal.has_handler_pending (this, //if no one listens, just kill it!
		            Signal.lookup ("tab-removed", typeof (DynamicNotebook)), 0, true)) {
		            var sure = tab_removed (tab);
		            if (sure)
		                remove_tab (tab);
		        } else
		            remove_tab (tab);
            });
            
            this.recalc_size ();
            
            return i;
        }
    }
    
}