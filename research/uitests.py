#!/usr/bin/env python3
# Charango interactive test cases

from view import *
import test_view

from gi.repository import GLib
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
        column.set_fixed_width(600)
        column.set_sizing(Gtk.TreeViewColumnSizing.FIXED)
        tree_view.append_column(column)

    if fixed_height:
        print("WARNING: DON'T use fixed height mode, see: "
              "https://bugzilla.gnome.org/show_bug.cgi?id=721597")
        tree_view.set_fixed_height_mode(True)
    tree_view.show()
    return tree_view


class UiTestApplication():
    def __init__(self):
        self.box = Gtk.Box(Gtk.Orientation.HORIZONTAL, 4)

    def add_button(self, callback):
        button = Gtk.Button('Tick')
        button.connect('clicked', callback)
        self.box.pack_start(button, True, False, 0)

    def run(self, data_source):
        self._data = data_source
        page = data_source.first_page()

        #tree_model = GtkTreeModelBasicShim(data_source)
        tree_model = GtkTreeModelLazyShim(data_source, 20)

        tree_view = create_gtk_tree_view_for(tree_model)
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(tree_view)
        scrolled_window.set_size_request(640, 480)
        self.box.pack_start(scrolled_window, True, True, 0)

        window = Gtk.Window()
        window.connect('delete-event', Gtk.main_quit)
        window.add(self.box)

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

    #numbers = ListSource(range(0,1000), 100)

    #live_numbers = LiveListSource(10, 10, initial_value_list=range(0,10))
    #GLib.timeout_add(500, live_numbers.tick)

    #data_source = numbers
    #data_source = tracker_test_data()
    #data_source = live_numbers
    data_source = test_view.EstimationTestSource(1000)
    #data_source = test_view.EstimationTestSource(16)
    app = UiTestApplication()

    def clicked_cb(button):
        live_numbers.add_row()

    #app.add_button(clicked_cb)
    app.run(data_source)
