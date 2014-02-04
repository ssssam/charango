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

    tree_view.set_fixed_height_mode(fixed_height)
    tree_view.show()
    return tree_view


class UiTestApplication():
    def __init__(self):
        box = Gtk.Box(Gtk.Orientation.HORIZONTAL, 4)

        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.set_size_request(640, 480)
        box.pack_start(scrolled_window, True, True, 0)

        window = Gtk.Window()
        window.connect('delete-event', Gtk.main_quit)
        window.add(box)

        self.window = window
        self.box = box
        self.view_container = scrolled_window

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
        self.view_container.add(tree_view)

        self.window.show_all()
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


def lazy_read_demo(app):
    '''
    Demo of lazily reading a source of 1000 rows.

    This source deliberately reveals its contents incrementally to demonstrate
    how this looks.
    '''
    data_source = test_view.EstimationTestSource(1000)
    app.run(data_source)


def add_row_test(app):
    '''
    Test adding items dynamically

    The list adds one of its items at random on each click.
    '''
    data_source = LiveListSource(10, 10)

    def clicked_cb(button):
        data_source.add_row()

    app.add_button(clicked_cb)

    # Make sure there's some scrolling, to highlight
    # https://bugzilla.gnome.org/show_bug.cgi?id=721597
    app.view_container.set_size_request(640, 80)

    app.run(data_source)


if __name__ == '__main__':
    install_debug_excepthook()

    #numbers = ListSource(range(0,1000), 100)

    #GLib.timeout_add(500, live_numbers.tick)

    #data_source = numbers
    #data_source = tracker_test_data()
    #data_source = live_numbers
    #data_source = test_view.EstimationTestSource(16)
    app = UiTestApplication()

    #lazy_read_demo(app)
    add_row_test(app)
