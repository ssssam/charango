# SPARQL Explorer UI

# Interesting ideas!
#  - select all resources of a certain type ... of course.
#  - your crazy music browser sparql ideas.
#  - play with SKOS ? to try to link to M.O?

import view

from gi.repository import Gio
from gi.repository import GLib
from gi.repository import Gtk
from gi.repository import Tracker
import gi.types

import sys


class SparqlExplorerApp(Gtk.Application):
    def __init__(self):
        Gtk.Application.__init__(self)
        GLib.set_application_name("SPARQL Explorer")
        GLib.set_prgname('sparql-explorer')

        self.db = None
        self.window = None

    def handle_sparql_changed(self, buffer):
        sparql = buffer.get_property('text')

        # FIXME: since this executes on every keypress, there's a
        # few considerations:
        #   - rate-limit the callbacks, no point in actually changing
        #   - on every press
        #   - need to free the old results pager, or you'll eat RAM.
        #   - need a way of reporting errors.
        tree_view = self.window.results_tree_view

        results_pager = view.TrackerQuery(
                self.db, sparql, 'class', '?class a rdfs:Class')
        gtk_tree_model = view.GtkTreeModelLazyShim(
                results_pager, viewport_n_rows=100)
        tree_view.set_model(gtk_tree_model)

        renderer = Gtk.CellRendererText()
        for index, title in enumerate(results_pager.columns()):
            column = Gtk.TreeViewColumn(title, renderer, text=index)
            column.set_fixed_width(600)
            column.set_sizing(Gtk.TreeViewColumnSizing.FIXED)
            tree_view.append_column(column)

    def create_window(self):
        window = Gtk.ApplicationWindow(
                application=self, title="SPARQL Explorer")

        paned = Gtk.Paned.new(Gtk.Orientation.VERTICAL)

        sparql_text_view = Gtk.TextView()
        self.sparql_text_buffer = sparql_text_view.get_buffer()
        self.sparql_text_buffer.connect('changed', self.handle_sparql_changed)

        results_tree_view = Gtk.TreeView()
        results_tree_view.set_fixed_height_mode(True)
        results_scroller = Gtk.ScrolledWindow()
        results_scroller.add(results_tree_view)
        paned.add1(sparql_text_view)
        paned.add2(results_scroller)

        window.add(paned)
        paned.show_all()

        window.sparql_text_view = sparql_text_view
        window.results_tree_view = results_tree_view
        return window

    def do_activate(self):
        if self.db is None:
            self.db = Tracker.SparqlConnection.get(None)
        if self.window is None:
            self.window = self.create_window()

        self.window.set_size_request(640, 480)

        # The text cannot change for now, because we need an
        # automated way of figuring out the root term of the query
        # ... will require a tokenizer and a simple algorithm.
        self.sparql_text_buffer.set_text(
                "SELECT ?class ?property {"
                "   ?class a rdfs:Class ."
                "   ?property a rdf:Property ; "
                "       rdfs:domain ?class"
                "} ORDER BY ?class ?property")
        self.window.sparql_text_view.set_editable(False)

        self.window.present()
        self.window.sparql_text_view.grab_focus()


def install_debug_excepthook():
    '''
    Force Gtk main loop to quit on unhandled Python exceptions.
    '''
    import pdb
    old_hook = sys.excepthook
    def new_hook(etype, evalue, etb):
        old_hook(etype, evalue, etb)
        for i in range(0, Gtk.main_level()):
            Gtk.main_quit()
        pdb.post_mortem(etb)
        sys.exit()
    sys.excepthook = new_hook


if __name__ == '__main__':
    install_debug_excepthook()
    SparqlExplorerApp().run(sys.argv)
