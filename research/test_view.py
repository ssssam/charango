import view
import uitests

from gi.repository import Gtk

import collections
import pytest


class ProfilingNumbersSource(view.NumbersSource):
    def __init__(self, page_size):
        super(ProfilingNumbersSource, self).__init__(page_size)
        self.queried_pages = collections.Counter()

    def _make_page(self, offset):
        self.queried_pages[offset] += 1
        return super(ProfilingNumbersSource, self)._make_page(offset)


class TestGtkTreeModelLazyShim:
    '''
    Show tree view with model and check that correct number of pages were queried.

    These tests are not perfect! Sometimes more or less pages are queried.
    Probably partly because we need to run xnest or disable all inputs to the
    widgets or some such.
    '''
    def run_widget(self, widget):
        widget.connect('draw', Gtk.main_quit)

        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(widget)

        window = Gtk.Window()
        window.add(scrolled_window)
        window.set_size_request(640, 480)
        window.show_all()
        Gtk.main()

    @pytest.fixture()
    def data(self):
        data = ProfilingNumbersSource(10)
        data.set_n_rows(100)
        return data

    @pytest.mark.parametrize(('fixed_height', 'expected_pages'), [
        (False, 10),
        (True, 10)
    ])
    def test_eager_loading(self, data, fixed_height, expected_pages):
        tree_model = view.GtkTreeModelBasicShim(data)
        tree_view = uitests.create_gtk_tree_view_for(tree_model, fixed_height=fixed_height)
        self.run_widget(tree_view)

        assert len(data.queried_pages.keys()) == expected_pages


    @pytest.mark.parametrize(('fixed_height', 'expected_pages'), [
        (False, 4),
        (True, 3)
    ])
    def test_lazy_loading(self, data, fixed_height, expected_pages):
        tree_model = view.GtkTreeModelLazyShim(data)
        tree_view = uitests.create_gtk_tree_view_for(tree_model, fixed_height=fixed_height)
        self.run_widget(tree_view)

        assert len(data.queried_pages.keys()) == expected_pages



test_queries = [
    ('SELECT ?class ?property ' 
     'WHERE {'
     '  ?class a rdf:Class .'
     '  ?property a rdfs:Property ;'
     '      rdf:domain ?class'
     '}'),
    ('SELECT ?artists '
     'WHERE ?type ?property {'
     '  rdfs:Class rdf:type ?type .'
     '  ?type rdf:range ?property '
     '}')
]
