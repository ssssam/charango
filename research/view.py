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

# Things to do on this:
#  - 

from gi.repository import GObject
from gi.repository import Gtk
from gi.repository import Tracker

import re

class CharangoRow():
    '''
    A single row in a CharangoPagedData model.
    '''
    def __init__(self, page_row_n, values, parent_page=None):
        self.page_row_n = page_row_n
        self.values = values
        self.parent_page = parent_page

        self.n_children = 0
        self.e_n_children = 0
        self.pages = []


class CharangoPage():
    '''
    A page of data.

    Rows are read from the data source one page at a time.
    '''
    def __init__(self, start_row_n=None, start_row_en=None,
                 prev_page=None, next_page=None):
        self.prev_page = prev_page
        self.next_page = next_page

        # Number of rows into the model
        if start_row_n and start_row_en:
            assert start_row_n == start_row_en
        self.start_row_n = start_row_n
        self.start_row_en = start_row_en

        self.rows = []

    def append_row(self, row):
        row = []

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

        # The root row is a special one that cannot be displayed, but has
        # the toplevel pages of the model as its children.
        self._root_row = None

    def _estimate_size(self):
        self.root_row = CharangoRow(None, 0)
        self.root_row._root_n_matches = self._count_matches(
                self.root_term, self.root_pattern)

        # What we should then do is query the 1st, last and middle page to get
        # a good idea of the overall number of rows, using the ratio of
        # root_n_matches / actual page_n_rows.

    def next_page(self, prev_page=None):
        if not self._root_row:
            assert prev_page is None, "First call to next_page() must be " \
                                      "to read the first page."
            self._estimate_size()

        if prev_page:
            if prev_page.next_page:
                return prev_page.next_page
            start_row_n = prev_page.start_row_n + len(prev_page.rows)
        else:
            start_row_n = 0

        cursor = self._run_query(offset=start_row_n, limit=self.page_size)

        def find_column(cursor, variable_name):
            n_columns = cursor.get_property('n-columns')
            for i in range(0, n_columns):
                if cursor.get_variable_name(i) == variable_name:
                    return i
            raise KeyError("Did not find %s in query results." % variable_name)

        root_column = find_column(cursor, self.root_term)

        page = CharangoPage(start_row_n=start_row_n, prev_page=prev_page)

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

            row = CharangoRow(page_row_n, values, parent_page=page)
            page.append_row(row)
            page_row_n += 1

        # This algorithm could be way more accurate, but since we need to cope
        # with inaccuracy it's good to have wildly wrong values right now
        # because it shows whether we are coping with reality well or not. ...
        #
        # The most obvious way to improve this is to read the last page as well
        # as the first, and maybe one in the middle. *THAT* is why you had an
        # 'initial_read' function, but still, it's nothing next_page() can't do
        # itself on the initial read.

        # FIXME: we should do this in the _estimate_size() method!

        self.root_row.e_row_count = (page_row_n / root_n_matches) * self.root_row._root_n_matches

        self.root_row.pages.append(page)

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
            len(self.root_row.pages[0].rows), self.root_row.e_n_children))

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

    def __init__(self, data):
        self.data = data


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

        data._show_estimation()


if __name__ == '__main__':
    ViewExample().run()

