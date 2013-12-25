# Charango interactive test cases

from view import *

from gi.repository import Gtk

import sys


def create_gtk_tree_view_for(tree_model, fixed_height=False):
    '''
    Create a rough GtkTreeView to display `tree_model`.
    '''
    tree_view = Gtk.TreeView(tree_model)

    renderer = Gtk.CellRendererText()
    for index, title in enumerate(tree_model.data.columns()):
        column = Gtk.TreeViewColumn(title, renderer, text=index)
        column.set_fixed_width(200)
        column.set_sizing(Gtk.TreeViewColumnSizing.FIXED)
        tree_view.append_column(column)

    if fixed_height:
        tree_view.set_fixed_height_mode(True)
    tree_view.show()
    return tree_view

class UiTestApplication():
    def run(self, data_source):
        self._data = data_source
        page = data_source.first_page()

        #tree_model = GtkTreeModelBasicShim(data_source)
        tree_model = GtkTreeModelLazyShim(data_source)
        self.demo_window(tree_model)

        #data._show_estimation()

    def demo_window(self, tree_model):
        window = Gtk.Window()
        window.connect('delete-event', Gtk.main_quit)

        tree_view = create_gtk_tree_view_for(tree_model, fixed_height=True)

        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(tree_view)
        scrolled_window.set_size_request(640, 480)
        window.add(scrolled_window)

        window.show_all()
        Gtk.main()


def install_debug_excepthook():
    '''
    Force Gtk main loop to quit on unhandled Python exceptions.
    '''
    from gi.repository import Gtk
    import pdb
    old_hook = sys.excepthook
    def new_hook(etype, evalue, etb):
        old_hook(etype, evalue, etb)
        for i in range(0, Gtk.main_level()):
            Gtk.main_quit()
        pdb.post_mortem(etb)
        sys.exit()
    sys.excepthook = new_hook


def tracker_test_data():
    connection = Tracker.SparqlConnection.get(None)
    data = TrackerQuery(
        connection,
        "SELECT ?class ?property {"
        "   ?class a rdfs:Class ."
        "   ?property a rdf:Property ; "
        "       rdfs:domain ?class"
        "} ORDER BY ?class ?property",
        "class", "?class a rdfs:Class")
    return data


if __name__ == '__main__':
    install_debug_excepthook()

    numbers = NumbersSource(20)
    numbers.set_n_rows(100000)

    #data_source = numbers
    data_source = tracker_test_data()
    UiTestApplication().run(data_source)
