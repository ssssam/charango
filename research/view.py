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

# Things to do on this still
# --------------------------
#
# Design the 'preferred' API! Mimicking GtkTreeModel is not ideal. But what is
# better? EggListBox uses a GSequence of elements, which supports like 1-5k
# rows, and just implements GtkContainer. That's no good for us because we
# can't add all the elements.  I think emitting row-added and row-removed on
# estimation changes is actually pretty reasonable. range-removed and
# range-added is even better.
#
# The real problem is, what if you want to use your PagedData to tell you stuff
# about the underlying query too, i.e. if you just want a live data model. You
# could argue that's Tracker's job ... which it is, but still, it doesn't exist.
# Could you build PagedData on top of it? No, because it would need to be lazy
# model... I guess what you'd want would be something that ate results from the
# cursor and remembered them and then emitted when soemthing had been added or
# changed. But you don't really *want* that unless you're trying to ORDER things
# .... so you don't need to separate these concepts at all!

from gi.repository import GObject
from gi.repository import Gtk
from gi.repository import Tracker

import re

class CharangoRow():
    '''
    A single row in a CharangoPagedData model.
    '''
    def __init__(self, data, page_row_n, values, parent_page=None):
        self.data = data
        self.page_row_n = page_row_n
        self.values = values
        self.parent_page = parent_page

        self.n_children = 0
        self.e_n_children = 0

        # FIXME: make this a GSequence
        self._pages = []

    def _store_page(self, page):
        for other_page in self._pages:
            if other_page.start_row_n > page.start_row_n:
                self._pages.insert(page, other_page)
        else:
            self._pages.append(page)

    def get_estimated_nth_child(self, estimated_n):
        # If row has not been read & has no estimated number of
        # children, read it now.

        # Now, we have estimated number of children. If estimated_n
        # > estimated_child_count, what do you do? Shouldn't ever
        # happen.

        # Next, find row object for 'estimated_n'. In the course
        # of this we need to find the page for the row. This
        # involves ... complexity!

        # Still, the complexity at this point is all in the underlying
        # model. We know the nearest in-memory page because we already
        # searched the list of pages for it ... 
        return some-kind-of-row-iter


class CharangoPage():
    '''
    A page of data.

    Rows are read from the data source one page at a time.
    '''
    def __init__(self, start_row_n=None, start_row_en=None):
        if start_row_n and start_row_en:
            assert start_row_n == start_row_en
        self.start_row_n = start_row_n
        self.start_row_en = start_row_en

        # FIXME: Make this a GSequence
        self._rows = []

    def append_row(self, row):
        self._rows.append(row)


class CharangoPagedData():
    '''
    Abstract lazy data model.

    Paged querying is built into this model. This makes it efficient when
    displaying data from large or slow data sources in a windowed view.
    (Although data sources in principle provide a row-by-row interface, this
    is usually an abstraction built upon a buffer in the data source. It would
    be better for us if the data source would expose a paged interface so that
    we could reuse the buffers inside the data source, instead of having to do
    our own, superflous paging).
    '''
    def __init__(self, page_size):
        self.page_size = page_size

    # old Calliope interface was:
    #  inital_read(node)
    #  read_page_at(head, tail, estimated_row_number)
    #  read_next_page(page)

    def next_page(self, current_page=None):
        '''
        Might be better if this only read the first page, and
        subsequent pages were read by a method on the page object...
        '''
        raise NotImplementedError()

    def page_for_row(self, head, tail, estimated_row_number):
        '''
        '''
        raise NotImplementedError()


class CharangoTrackerQuery(CharangoPagedData):
    '''
    This model provides a Charango data model from a Tracker query.

    Paged internally, using OFFSET and LIMIT, which gives the following
    benefits:
       - expensive (slow) queries do not slow down the view too much
       - memory use can be kept low, if required
       - huge amounts of data can be viewed.
    '''

    def __init__(self, connection, query, root_term, root_pattern,
                 page_size=1200):
        '''
        Finding ``root_term`` and ``root_pattern`` could be done automatically
        by parsing ``query``, but that's too much effort for now.

        :param query: A SPARQL query.
        :param root_term: The root term, which is usually the primary sort key
            of ``query``.
        :param root_pattern: The triple pattern from ``query`` that matches
            ``root_term``
        '''
        super(CharangoTrackerQuery, self).__init__(page_size)

        self.connection = connection
        self.query = query
        self.root_term = root_term
        self.root_pattern = root_pattern

        # No support for multi-level queries ... for now...
        self.depth = 1

        # The root row is a special one that cannot be displayed, but has
        # the toplevel pages of the model as its children.
        self._root_row = None

    def _estimate_size(self):
        self.root_row = CharangoRow(self, None, 0)
        self.root_row._root_n_matches = self._count_matches(
                self.root_term, self.root_pattern)

        # What we should then do is query the 1st, last and middle page to get
        # a good idea of the overall number of rows, using the ratio of
        # root_n_matches / actual page_n_rows. However, for now having a wildly
        # inaccurate number is actually quite useful.
        first_page = self._read_page_at(self.root_row, 0)

        root_to_row_ratio = len(first_page._rows) / first_page._root_n_matches
        self.root_row.e_row_count = root_to_row_ratio * self.root_row._root_n_matches


    def _read_page_at(self, parent_row, start_row_n):
        '''
        Query one page worth of rows from the database, starting at ``offset``.

        This function adds the page to the row's list of pages, and returns it.
        '''
        cursor = self._run_query(offset=start_row_n, limit=self.page_size)

        def find_column(cursor, variable_name):
            n_columns = cursor.get_property('n-columns')
            for i in range(0, n_columns):
                if cursor.get_variable_name(i) == variable_name:
                    return i
            raise KeyError("Did not find %s in query results." % variable_name)

        root_column = find_column(cursor, self.root_term)

        page = CharangoPage(start_row_n=start_row_n)

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

            row = CharangoRow(parent_row, page_row_n, values)
            page.append_row(row)
            page_row_n += 1

        page._root_n_matches = root_n_matches
        parent_row._store_page(page)
        return page

    def next_page(self, prev_page=None):
        if not self._root_row:
            assert prev_page is None, "First call to next_page() must be " \
                                      "to read the first page."
            self._estimate_size()

        if prev_page:
            if prev_page.next_page:
                return prev_page.next_page
            start_row_n = prev_page.start_row_n + len(prev_page._rows)
        else:
            start_row_n = 0

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
        print("Root (primary sort key): %i values" % self.root_row._root_n_matches)
        print("Page %i rows total: estimated total row count %i" % (
            len(self.root_row._pages[0]._rows), self.root_row.e_n_children))

        cursor = self.connection.query(self.query, None)
        n_rows = 0
        while cursor.next(None):
            n_rows += 1
        print("Actual row count: %i" % n_rows)


class CharangoGtkTreeModel(GObject.Object, Gtk.TreeModel):
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
        super(CharangoGtkTreeModel, self).__init__()
        self.data = data

    def _get_row_from_iter(self, iter):
        if iter is None:
            return self._root_row
        # FIXME: read rowiter from iter

    def do_get_flags(self):
        return 0

    def do_get_n_columns(self):
        first_page = self.data.root_row._pages[0]
        n_columns = len(first_page._rows[0].values)
        return n_columns

    def do_get_column_type(self, index):
        return str

    def do_get_iter(self, path):
        if not (0 < path.get_depth() < self.data.depth):
            return (False, None)

        iter = None
        for i in path.get_indices():
            iter = self.do_iter_nth_child(iter, i)
            if not iter:
                return (False, iter)
        return (True, iter)

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
        return 'Foo'

    def do_iter_next(self, iter):
        return None

    def do_iter_previous(self, iter):
        return None

    def do_iter_children(self, iter):
        return None

    def do_iter_has_child(self, iter):
        return False

    def do_iter_n_children(self, iter):
        return 0

    def do_iter_nth_child(self, parent_iter, estimated_n):
        # FIXME: should be implemented in terms of a base class
        # function.
        parent_row = self._get_row_from_iter(parent_iter)

        if not parent_row:
            return None

        row = row.get_estimated_nth_child(estimated_n)

        return self._get_iter_for_row(row)

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
        data = CharangoTrackerQuery(
            connection,
            "SELECT ?class ?property {"
            "   ?class a rdfs:Class ."
            "   ?property a rdf:Property ; "
            "       rdfs:domain ?class"
            "} ORDER BY ?class ?property",
            "class", "?class a rdfs:Class")

        page = data.next_page()

        tree_model = CharangoGtkTreeModel(data)
        self.demo_window(tree_model)

        #data._show_estimation()

    def demo_window(self, tree_model):
        window = Gtk.Window()
        window.connect('delete-event', Gtk.main_quit)

        tree_view = Gtk.TreeView(tree_model)
        window.add(tree_view)

        window.show_all()
        Gtk.main()

# Test inserting and removing data from Tracker!
# Add some contacts, since you don't use those ;)


if __name__ == '__main__':
    ViewExample().run()

