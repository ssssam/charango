import view
import uitests

from gi.repository import GLib
from gi.repository import Gtk

import collections
import pytest

@pytest.fixture(autouse=True)
def debug_excepthook():
    '''
    Install debug exception handler.

    This is important so that when exceptions are raised in Python functions
    that are callbacks from GLib/GTK+/other C code, the debugger is started.
    The default behaviour is to just dump the exception on stderr and continue
    which can lead to infinite loops. If py.test is not invoked with the '-s'
    option an infinite loop will still occur. FIXME: this could definitely
    be improved upon!
    '''
    uitests.install_debug_excepthook()

# Awkward sources you could come up with.


class IdentitySource(view.PagedDataInterface):
    '''
    Data source in which the value of a row is its row number.

    This is the only source which descends from PagedDataInterface directly
    rather than PagedData (and probably the only possible source where that
    makes sense).
    '''
    def __init__(self, n_rows, page_size, transform=None):
        super(IdentitySource, self).__init__()
        self.page_size = page_size
        self.n_rows = n_rows
        self.transform_func = transform

    def columns(self):
        return ["Value"]

    # To do: dynamic resizing ....
    #def set_n_rows(self, n_rows):
    #    assert n_rows >= 0
    #    self._n_rows = n_rows
    #    self._estimated_n_rows = self._n_rows

    def estimate_row_count(self):
        return self.n_rows

    def _make_page(self, offset):
        if self.transform_func is not None:
            def transform(n): return self.transform_func(n)
        else:
            def transform(n): return n

        assert offset < self.n_rows
        rows = []
        for i in range(0, self.page_size):
            if offset+i >= self.n_rows:
                break
            values = [transform(int(offset+i))]
            rows.append(view.Row(values))

        page = view.Page(offset=int(offset), rows=rows)
        return page

    def first_page(self):
        return self._make_page(0)

    def next_page(self, prev_page):
        if prev_page.offset + len(prev_page._rows) >= self.n_rows:
            return None
        return self._make_page(prev_page.offset + self.page_size)

    def get_page_for_position(self, position):
        assert 0.0 <= position <= 1.0
        if position == 1.0:
            offset = self.n_rows - 1
        else:
            offset = self.n_rows * position
        offset -= (offset % self.page_size)
        return self._make_page(offset)


class SourceTests:
    @pytest.fixture()
    def source(self):
        source = view.IdentitySource(100, 10)
        return source

    def test_page_forwards(self, source):
        page = None
        for i in range(0, 10):
            page = source.next_page(prev_page=page)
            assert page.offset == i * 10
        assert source.next_page(prev_page=page) == None

    # We don't implement page backwards yet!

    def test_get_page_for_position(self, source):
        # How would you test this?
        for i in range(0, 100):
            page = source.get_page_for_position(100 / i)
            assert page.offset <= i < (page.offset + len(page._rows))

# To test _find_row() ...
# 

class TestFindRow():
    def make_test_source(self, values, page_size=None):
        page_size = page_size or len(values)
        return view.ListSource(values, page_size)

    def test_simple(self):
        '''
        Basic test of performing a binary search for a specific row.
        '''
        source = self.make_test_source([1,3,5,7,9])
        def key(row): return row.values[0]
        for n, value in enumerate([1,3,5,7,9]):
            print("Locate %i" % value)
            found_row, found_page, row_offset = source._find_row(value, key)
            assert found_row.values == [value]
            assert found_page == source.first_page()
            assert row_offset == n
        for n, value in enumerate([0,2,4,6,8,10]):
            found_row, found_page, row_after_offset = source._find_row(value, key)
            assert found_row == None
            assert found_page == source.first_page()
            assert row_after_offset == n


class EstimationTestSource(view.PagedData):
    '''
    This source assumes it has 3*page_size rows to begin with.

    This class may have stuff in common with the TrackerSource which you could
    move into a base class ... its own base class or PagedData ??
    '''
    def __init__(self, real_n_rows):
        super(EstimationTestSource, self).__init__(query_size=10)
        self.real_data = list(range(0, real_n_rows))
        self._estimated_n_rows = self.query_size * 3

    def columns(self):
        return ['Value']

    def estimate_row_count(self):
        return self._estimated_n_rows

    def _update_estimated_size(self, estimated_n_rows, known_n_rows):
        super(EstimationTestSource, self)._update_estimated_size(estimated_n_rows, known_n_rows)
        self._estimated_n_rows = estimated_n_rows

    def _read_and_store_page(self, offset, prev_page=None):
        print ("EstimationTestSource: _read_and_store_page(%i, prev_page=%s), "
               "real data %i" % (offset, prev_page, len(self.real_data)))
        if offset >= len(self.real_data):
            raise view.NoDataError
        values = self.real_data[offset:offset+self.query_size]

        rows = [view.Row([value]) for i, value in enumerate(values)]
        page = view.Page(offset, rows)
        self._store_page(page, prev_page=prev_page)
        return page


@pytest.fixture()
def overestimated_source():
    return EstimationTestSource(real_n_rows=16)

@pytest.fixture()
def underestimated_source():
    return EstimationTestSource(real_n_rows=100)


class TestSizeEstimation:
    '''
    Test where actual data is undersized compared to original estimate.
    '''
    def test_under_0_8(self, underestimated_source):
        source = underestimated_source
        assert source.estimate_row_count() == 30

        page = source.get_page_for_position(0.8)
        assert source.estimate_row_count() == 100
        assert page.offset == 80
        assert len(page._rows) == 10

    def test_over_0_4(self, overestimated_source):
        source = overestimated_source
        assert source.estimate_row_count() == 30

        # Actually 16 rows, 0.4 * 16 = 6
        page = source.get_page_for_position(0.4)
        assert page.offset == 0
        assert len(page._rows) == 10

        assert source.estimate_row_count() == 16
        source.get_page_for_position(0.4)

    def test_over_0_8(self, overestimated_source):
        source = overestimated_source
        source.get_page_for_position(0.8)
        source.get_page_for_position(0.8)

    def test_over_1_0(self, overestimated_source):
        source = overestimated_source
        source.get_page_for_position(1.0)
        source.get_page_for_position(1.0)

##########

class ProfilingNumbersSource(IdentitySource):
    def __init__(self, n_rows, page_size):
        super(ProfilingNumbersSource, self).__init__(n_rows, page_size)
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
        def timeout():
            Gtk.main_quit()
        GLib.timeout_add_seconds(1, timeout)

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
        data = ProfilingNumbersSource(100, 10)
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
        '''
        Create a lazy GtkTreeModel over a 10 page 100 row data source.

        The 'expected_pages' parameter marks how many of the pages of the
        model the GtkTreeModel is expected to query.
        '''
        tree_model = view.GtkTreeModelLazyShim(data, viewport_n_rows=10)
        tree_view = uitests.create_gtk_tree_view_for(tree_model, fixed_height=fixed_height)
        self.run_widget(tree_view)

        assert len(data.queried_pages.keys()) == expected_pages

    def test_overestimated_source(self):
        data = overestimated_source()

        tree_model = view.GtkTreeModelLazyShim(data, viewport_n_rows=10)
        tree_view = uitests.create_gtk_tree_view_for(tree_model, fixed_height=False)
        self.run_widget(tree_view)

    def test_underestimated_source(self):
        data = underestimated_source()

        tree_model = view.GtkTreeModelLazyShim(data, viewport_n_rows=10)
        tree_view = uitests.create_gtk_tree_view_for(tree_model, fixed_height=False)
        self.run_widget(tree_view)


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
