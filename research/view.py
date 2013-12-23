# Charango view experiment, 2013 edition
# Python 3!

# Goal: dynamic views.
#
# For example, I want to create a view of ontology > class > property.
# You can do:
#  SELECT ?ontology ?class ?property {
#       ?ontology a tracker:Ontology .
#       ?class a rdfs:Class ;
#           FILTER(fn:starts-with(?class, ?ontology))
#       ?property a rdf:Property ;
#           rdf:domain ?class
#  } ORDER BY ?ontology, ?class, ?property
#
# actually, you can't because fn:starts-with needs a string literal
# as its second argument ...

from gi.repository import GObject
from gi.repository import Gtk
from gi.repository import Tracker

import ctypes
import random
import re
import sys


class Row():
    '''
    Base class single row in a Charango model.

    Currently we assume all rows are leaf rows (no children). When extending
    Charango to display trees as well as just lists, this class should probably
    start to implement PagedDataInterface.
    '''
    def __init__(self, parent_page, relative_n, values):
        '''
        :param relative_n: Row number relative to ``parent_page``
        '''
        self.parent_page = parent_page
        self.relative_n = relative_n
        self.values = values


class Page():
    '''
    A page of data.

    The data within a page is not subject to change unless the underlying data
    changes.
    '''
    def __init__(self, offset=None):
        self.offset = offset

        # FIXME: Make this a GSequence, perhaps
        self._rows = []

    def __str__(self):
        return "<Page %x offset %i, %i rows>" % (id(self), self.offset, len(self._rows))

    def append_row(self, row):
        '''
        FIXME: should add them all at once
        '''
        self._rows.append(row)

    def row(self, n):
        return self._rows[n]


class PagedDataInterface():
    '''
    Abstract lazy data model.

    Paged querying is built into this model. This makes it efficient when
    displaying data from large or slow data sources in a windowed view.
    (Although data sources in principle provide a row-by-row interface, this
    is usually an abstraction built upon a buffer in the data source. It would
    be better for us if the data source would expose a paged interface so that
    we could reuse the buffers inside the data source, instead of having to do
    our own, additional paging).

    The API is designed to encourage querying one page at a time, so that page
    sizes can be coordinated with the query engine and the view mechanism.
    Iterating through every page may be very slow.
    '''
    def __init__(self, page_size):
        '''
        Pages will contain from 1 to ``page_size`` rows.

        :param page_size: Number of rows to be read per page
        '''
        self.page_size = page_size

        # FIXME: make this a GSequence
        self._pages = []

        self._n_rows = None
        self._estimated_n_rows = self._estimate_row_count()

    def _store_page(self, page, prev_page=None):
        if prev_page is None:
            for prev_page in self._pages:
                if prev_page.offset > page.offset:
                    break
        if prev_page is not None:
            self._pages.insert(self._pages.index(prev_page), page)
        else:
            self._pages.append(page)

    def _estimate_row_count(self):
        '''
        Count or estimate the number of rows in the data.

        This function can query data from the source but the query *must* be
        fast. The number of child rows does not have to be exact if returning
        an exact number would take too long, but the more inaccuracy the less
        exact the scroll bar is for the user. This is a trade-off that must be
        worked out for your specific use case.
        '''
        raise NotImplementedError()

    def _read_and_store_page(self, offset, prev_page=None):
        '''
        '''
        raise NotImplementedError()

    def first_page(self):
        '''
        Return the first page, querying for it if necessary.
        '''
        return self.next_page(prev_page=None)

    def next_page(self, prev_page=None):
        '''
        Return the page after 'prev_page', querying for it if necessary.

        This may involve an expensive database read. Therefore, we do not
        expose a standard Python iterator interface for pages because a
        'for page in data' loop might take hours.
        '''
        if prev_page:
            assert prev_page in self._pages
            assert len(prev_page._rows) == self.page_size
            expected_offset = prev_page.offset + self.page_size
            expected_index = self._pages.index(prev_page) + 1
        else:
            expected_offset = 0
            expected_index = 0

        try:
            page = self._pages[expected_index]
            assert page.offset >= expected_offset
            if page.offset == expected_offset:
                return page
        except IndexError:
            pass

        page = self._read_and_store_page(expected_offset, prev_page=prev_page)
        return page

    # def prev_page():
    #   We'll need this eventually too!

    def get_page_for_position(self, position):
        '''
        Return the page at ``position``.

        The ``position`` parameter is specified as a floating point value
        between 0 and 1, where 0 is the first page and 1 the last. Other than
        the edge values, the accuracy is unspecified. This is necessary when
        using a lazy data model -- to have an accurate idea of the scale of the
        underlying data would require querying every row!
        '''
        assert 0.0 <= position <= 1.0

        estimated_start_row_n = position * self._estimated_n_rows
        estimated_start_row_n -= estimated_start_row_n % self.page_size

        page = None
        for page in self._pages:
            if page.offset == estimated_start_row_n:
                return page
            if page.offset > estimated_start_row_n:
                break
        prev_page = page

        page = self._read_and_store_page(estimated_start_row_n, prev_page=prev_page)

        return page


class TrackerQuery(PagedDataInterface):
    '''
    This model provides a paged data model from a Tracker query.

    Paged internally, using OFFSET and LIMIT, which gives the following
    benefits:
       - expensive (slow) queries do not slow down the view too much
       - memory use can be kept low, if required
       - huge amounts of data can be viewed.
    '''

    def __init__(self, connection, query, root_term, root_pattern,
                 page_size=100):
        '''
        Finding ``root_term`` and ``root_pattern`` could be done automatically
        by parsing ``query``, but that's too much effort for now.

        :param query: A SPARQL query.
        :param root_term: The root term, which is usually the primary sort key
            of ``query``.
        :param root_pattern: The triple pattern from ``query`` that matches
            ``root_term``
        '''
        self.connection = connection
        self.query = query
        self.root_term = root_term
        self.root_pattern = root_pattern

        super(TrackerQuery, self).__init__(page_size)

        # No support for multi-level queries ... for now...
        self.depth = 1

        # The root row is a special one that cannot be displayed, but has
        # the toplevel pages of the model as its children.

    def _estimate_row_count(self):
        self._root_n_matches = self._count_matches(
                self.root_term, self.root_pattern)

        # What we should then do is query the 1st, last and middle page to get
        # a good idea of the overall number of rows, using the ratio of
        # root_n_matches / actual page_n_rows. However, for now having a wildly
        # inaccurate number is actually quite useful.
        first_page = self._read_and_store_page(0)

        root_to_row_ratio = len(first_page._rows) / first_page._root_n_matches

        # FIXME: this algorithm could be improved a lot. First idea: now that
        # we know the expected total row count, query the last page and see
        # how far off we are. Basically we want to do a binary search for the
        # last page, up to a certain error margin / number of tries.

        return root_to_row_ratio * self._root_n_matches

    def _read_and_store_page(self, offset, prev_page=None):
        '''
        Query one page worth of rows from the database, starting at ``offset``.

        This function adds the page to the row's list of pages, and returns it.
        '''
        cursor = self._run_query(offset=offset, limit=self.page_size)

        def find_column(cursor, variable_name):
            n_columns = cursor.get_property('n-columns')
            for i in range(0, n_columns):
                if cursor.get_variable_name(i) == variable_name:
                    return i
            raise KeyError("Did not find %s in query results." % variable_name)

        root_column = find_column(cursor, self.root_term)

        page = Page(offset)

        rows = []
        page_row_n = 0
        root_n_matches = 0
        root_value = None
        n_columns = cursor.get_property('n-columns')
        while cursor.next(None):
            new_root_value = cursor.get_string(root_column)[0]
            if root_value != new_root_value:
                root_value = new_root_value
                root_n_matches += 1

            values = []
            for i in range(0, n_columns):
                values.append(cursor.get_string(i)[0])

            row = Row(page, page_row_n, values)
            page.append_row(row)
            page_row_n += 1

        page._root_n_matches = root_n_matches
        self._store_page(page)
        return page

    def _count_matches(self, term, pattern):
        '''
        Count number of matches returned for a single triple pattern.
        '''
        count_query = 'SELECT COUNT(?%s) WHERE { %s }' % (term, pattern)
        cursor = self.connection.query(count_query, None)
        assert cursor.get_property('n-columns') == 1
        cursor.next(None)
        return cursor.get_integer(0)

    def _run_query(self, offset, limit):
        query = self.query + ' OFFSET %i LIMIT %i' % (offset, limit)
        cursor = self.connection.query(query, None)
        return cursor

    def _show_estimation(self):
        print("Root (primary sort key): %i values" % self._root_n_matches)
        print("Page %i rows total: estimated total row count %i" % (
            len(self._pages[0]._rows), self._estimated_n_rows))

        cursor = self.connection.query(self.query, None)
        n_rows = 0
        while cursor.next(None):
            n_rows += 1
        print("Actual row count: %i" % n_rows)


class GtkTreeModelLazyShim(GObject.Object, Gtk.TreeModel):
    '''
    Adapter for GtkTreeView to allow its use with a lazy data model.

    This is a non-trivial piece of code, because GtkTreeView is a bit too
    industrious and queries all of the rows in the model straight away on load.

    We square this circle by spoofing results for GtkTreeView -- we assume that
    it will only actually be displaying a few hundred rows at any one time, so
    we don't actually have to query all of the data up front. Instead, we
    gather the first few hundred rows from the query, and the last few hundred,
    and use that to estimate the overall size of the model. The size simply
    affects the size of the scroll bar in most cases, so a little inaccuracy
    doesn't matter too much.

    This probably all only works in fixed height mode right now. It is all
    rather horrible, but it beats rewriting GtkTreeView.
    '''

    '''
    Iterator layout.

    Needs to track:
       - starting row N and whether we are in freefall
       - could just track row object, no?
       - better if it had a *list iterator* which pointed to the row object!!!

    Really, the underlying model should expose an iterator object, and the
    GtkTreeModel implementation just needs to use that as its iter and then
    track whether the iter is in 'freefall' or not.
    '''

    def __init__(self, data):
        super(GtkTreeModelLazyShim, self).__init__()

        self.data = data

        self._iter_page = dict()
        self.invalidate_iters()

    def invalidate_iter(self, iter):
        iter.stamp = 0
        if iter.user_data:
            if iter.user_data in self._iter_page:
                del self._iter_page[iter.user_data]
            iter.user_data = None

    def invalidate_iters(self):
        self.stamp = random.randint(-2147483648, 2147483647)
        self._iter_page.clear()

    def _create_iter(self, page_container, page, relative_row_n, loose_count):
        iter = Gtk.TreeIter()
        iter.stamp = self.stamp
        self._update_iter(iter, page_container, page, relative_row_n, loose_count)
        return iter

    def _update_iter(self, iter, page_container, page, relative_row_n, loose_count=0):
        # ``page_container`` is ignored because currently we only support flat
        # lists anyway.
        iter.user_data = id(page)
        self._iter_page[iter.user_data] = page
        iter.user_data2 = relative_row_n
        iter.user_data3 = loose_count
        return iter

    def _unpack_iter(self, iter):
        '''
        Return tuple of (page container, page, row number inside page)
        '''
        if iter is None:
            return self.data, None, 0, 0
        else:
            return self.data, self._iter_page[iter.user_data], iter.user_data2, iter.user_data3

    def do_get_flags(self):
        return 0

    def do_get_n_columns(self):
        first_page = self.data.first_page()
        n_columns = len(first_page._rows[0].values)
        print("GtkTreeModel: n_columns: %i" % n_columns)

        return n_columns

    def do_get_column_type(self, index):
        return str

    def do_get_iter(self, path):
        #if not (0 < path.get_depth() < self.data.depth):
        iter = None
        if path.get_depth() != 1:
            pass
        else:
            for i in path.get_indices():
                have_iter, iter = self.do_iter_nth_child(iter, i)
        print("GtkTreeModel: get_iter: %s ->  %s" % (path, iter))
        return (iter is not None, iter)

    def do_get_path(self, iter):
        '''
        All indices in path may be estimated!

        Row numbers may change if you call any methods on the model that query
        more data from the data source! Use a GtkTreeRowReference if you want
        to hold a long-term reference!
        '''
        if not iter:
            return Gtk.TreePath.new_first()

        # 1. Get row number / estimated row number from the iter
        # 2. Call iter_parent() and get row numbers from the parent.
        # 3. GOTO 2
        path = Gtk.TreePath()
        return path

    def do_get_value(self, iter, column):
        # Easy!
        print("GtkTreeModel: get_value: %s (%s) %i" % (iter, iter.user_data, column))
        page_container, page, row_n, loose_count = self._unpack_iter(iter)
        if loose_count > 0:
            # This iter should be invisible!
            return 'invisible'
            #print("Warning: returning iter with loose count %i to normal" % loose_count)
            #self._update_iter(iter, page_container, page, row_n, 0)
        print("row %i in %s" % (row_n, page)) 
        row = page.row(row_n)
        return row.values[column]

    def do_iter_next(self, iter):
        page_container, page, row_n, loose_count = self._unpack_iter(iter)
        if loose_count > 0:
            if row_n + loose_count >= page_container._estimated_n_rows:
                print("GtkTreeModel: iter_next: %s is done" % (iter))
                return None
            else:
                print("GtkTreeModel: iter_next: %s (%i) is loose, at %i, loose "
                      "count %i" % (iter, iter.user_data, row_n, loose_count))
                return self._update_iter(iter, self.data, page, row_n, loose_count+1)
        if row_n + 1< len(page._rows):
            iter.user_data2 = row_n + 1
            print("GtkTreeModel: iter_next: %s to row %i" % (iter, row_n + 1))
            return iter
        else:
            # Set this iter loose! No more real data for you!
            return self._update_iter(iter, self.data, page, row_n, 1)

    def do_iter_previous(self, iter):
        return None

    def do_iter_children(self, iter):
        return None

    def do_iter_has_child(self, iter):
        has_child = True if iter is None else False
        print("GtkTreeModel: iter_has_child: %s: %i" % (iter, has_child))
        return has_child

    def do_iter_n_children(self, iter):
        print("GtkTreeModel: iter_n_children: %s %i" % (iter, 0))
        return 0

    def do_iter_nth_child(self, parent_iter, estimated_n):
        pages, page, page_row_n, loose_count = self._unpack_iter(parent_iter)

        # Should never happen because we return 'has_child' == False for all
        # iters other than the root iter ...
        assert page is None and page_row_n == 0 and loose_count == 0

        print("GtkTreeModel: iter_nth_child: %s, %i" % (parent_iter, estimated_n))

        relative_row_n = estimated_n % pages.page_size
        if estimated_n < self.data.page_size:
            page = pages.first_page()
            row = page.row(relative_row_n)
        else:
            estimated_position = estimated_n / pages._estimated_n_rows
            page = pages.get_page_for_position(estimated_position)
            print("got page %s for row %i" % (page, relative_row_n))

            try:
                row = page.row(relative_row_n)
            except IndexError:
                # row is off the bottom of the model ... 
                return (False, None)

        iter = self._create_iter(self.data, page, relative_row_n, False)
        return (True, iter)

    def do_iter_parent(self, child_iter):
        return None


test_queries = [
    dict(query=
        "SELECT ?class ?property {"
        "   ?class a rdfs:Class ."
        "   ?property a rdf:Property ; "
        "       rdfs:domain ?class"
        "} ORDER BY ?class ?property",
        root_term="class", root_pattern="?class a rdfs:Class"),
]


class ViewExample():
    def run(self):
        connection = Tracker.SparqlConnection.get(None)
        data = TrackerQuery(
            connection,
            "SELECT ?class ?property {"
            "   ?class a rdfs:Class ."
            "   ?property a rdf:Property ; "
            "       rdfs:domain ?class"
            "} ORDER BY ?class ?property",
            "class", "?class a rdfs:Class")

        page = data.first_page()

        tree_model = GtkTreeModelLazyShim(data)
        self.demo_window(tree_model)

        #data._show_estimation()

    def demo_window(self, tree_model):
        window = Gtk.Window()
        window.connect('delete-event', Gtk.main_quit)

        tree_view = Gtk.TreeView(tree_model)
        columns = ["Class", "Property"]
        renderer = Gtk.CellRendererText()
        for index, title in enumerate(columns):
            column = Gtk.TreeViewColumn(title, renderer, text=index)
            column.set_sizing(Gtk.TreeViewColumnSizing.FIXED)
            tree_view.append_column(column)
        tree_view.set_fixed_height_mode(True)

        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(tree_view)
        scrolled_window.set_size_request(640, 480)
        window.add(scrolled_window)

        window.show_all()
        Gtk.main()

# Test inserting and removing data from Tracker!
# Add some contacts, since you don't use those ;)

def install_debug_excepthook():
    '''
    Force Gtk main loop to quit on unhandled Python exception
    '''
    from gi.repository import Gtk
    old_hook = sys.excepthook
    def new_hook(etype, evalue, etb):
        old_hook(etype, evalue, etb)
        for i in range(0, Gtk.main_level()):
            Gtk.main_quit()
        sys.exit()
    sys.excepthook = new_hook

if __name__ == '__main__':
    install_debug_excepthook()

    ViewExample().run()


