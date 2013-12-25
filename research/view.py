# Charango view experiment, 2013 edition
# Python 3!

# For tomorrow: work out how to tell that an iter is *not* loose
# any longer, because the viewport has moved!

# Steps to prototype:
#  - adding & removing
#  - you're having a bad time with Tracker because you don't check and adjust
#    the estimation on further page reads. Recalc after every page read?
#  - also needs to try and find the end straight away
#  - test data sources:
#     incrementing numbers,
#     a prime numbers one,
#     one that adds and removes regularly
#  - app with Tracker query on one side and list of results on other

# Automated tests:
# - Add lazy model to GtkTreeView with & without fixed height & fixed widths,
#   make sure that after loading only a couple of pages are in memory.
# - Jump scrollbar and make sure only a few other pages are in memory.
# - Jump to end and ""

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
import gi.types

import ctypes
import inspect
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

    def __repr__(self):
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

    def _store_page(self, page, prev_page=None):
        assert len(page._rows) > 0

        if prev_page is None:
            index_after = 0
            for index_after, next_page in enumerate(self._pages):
                if next_page.offset > page.offset:
                    break
            else:
                index_after += 1
        else:
            index_after = self._pages.index(prev_page)+1

        if index_after > 0 and len(self._pages) > 0:
            assert self._pages[index_after-1].offset < page.offset
        if index_after < len(self._pages):
            assert self._pages[index_after].offset > page.offset
        self._pages.insert(index_after, page)
        print("store %s before %i (total %i)" % (page, index_after, len(self._pages)))

    def estimate_row_count(self):
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
            #assert len(prev_page._rows) == self.page_size
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


class NumbersSource(PagedDataInterface):
    '''
    Simple deterministic data source that provides incrementally numbered rows.
    '''
    def __init__(self, page_size):
        super(NumbersSource, self).__init__(page_size)

    def columns(self):
        return ["Number"]

    def set_n_rows(self, n_rows):
        assert n_rows >= 0
        self._n_rows = n_rows
        self._estimated_n_rows = self._n_rows

    def estimate_row_count(self):
        return self._n_rows

    def _make_page(self, offset):
        assert offset < self._n_rows
        page = Page(offset=int(offset))
        for i in range(0, self.page_size):
            if offset+i >= self._n_rows:
                break
            row = Row(page, i, [int(offset+i)])
            page.append_row(row)
        return page

    def first_page(self):
        return self._make_page(0)

    def next_page(self, prev_page):
        if prev_page.offset + len(prev_page._rows) >= self._n_rows:
            return None
        return self._make_page(prev_page.offset + self.page_size)

    def get_page_for_position(self, position):
        assert 0.0 <= position <= 1.0
        if position == 1.0:
            offset = self._n_rows - 1
        else:
            offset = self._n_rows * position
        offset -= (offset % self.page_size)
        return self._make_page(offset)


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

        self._estimated_n_rows = None

    def columns(self):
        # FIXME: don't hardcode
        return ['Class', 'Property']

    def estimate_row_count(self):
        if self._estimated_n_rows is not None:
            return self._estimated_n_rows

        self._root_n_matches = self._count_matches(
                self.root_term, self.root_pattern)

        # What we should then do is query the 1st, last and middle page to get
        # a good idea of the overall number of rows, using the ratio of
        # root_n_matches / actual page_n_rows. However, for now having a wildly
        # inaccurate number is actually quite useful.
        first_page = self.first_page()

        root_to_row_ratio = len(first_page._rows) / first_page._root_n_matches

        # FIXME: this algorithm could be improved a lot. First idea: now that
        # we know the expected total row count, query the last page and see
        # how far off we are. Basically we want to do a binary search for the
        # last page, up to a certain error margin / number of tries.

        self._estimated_n_rows = root_to_row_ratio * self._root_n_matches
        return self._estimated_n_rows

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

        # FIXME: if last page, set a flag? Is there a way to spot the last
        # page if it happens to finish at LIMIT rows?

        if len(page._rows) == 0:
            return None

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



class GInterfaceTraceMetaclass(gi.types.GObjectMeta):
    '''
    Metaclass which traces methods that implement GObject interface functions.
    '''
    @staticmethod
    def _trace_call(method):
        def wrapper(*args, **kwargs):
            assert method.__name__.startswith('do_')

            obj = args[0]
            def arg_to_str(arg):
                if isinstance(arg, Gtk.TreeIter):
                    try:
                        container, page, row_offset = obj._unpack_iter(arg)
                        return "<iter: p%i r%i>" % (page.offset, row_offset)
                    except KeyError:
                        return "<iter: invalid>"
                else:
                    return str(arg)

            p_args = []
            p_args.extend([arg_to_str(a) for a in args[1:]])
            p_args.extend(["%s=%s" % (k, arg_to_str(v)) for k, v in kwargs])
            print ("%s(%s)" % (method.__name__, ', '.join(p_args)))
            return method(*args, **kwargs)
        return wrapper

    def __new__(cls, classname, bases, classdict):
        for name, value in list(classdict.items()):
            if inspect.isfunction(value) and name.startswith('do_'):
                classdict['_GInterfaceTraceMetaclass_%s' % name] = value
                classdict[name] = GInterfaceTraceMetaclass._trace_call(value)
        return type.__new__(cls,classname,bases,classdict)


class GtkTreeModelBasicShim(GObject.Object, Gtk.TreeModel):#,
                            #metaclass=GInterfaceTraceMetaclass):
    '''
    Basic GtkTreeView adapter for paged data models.

    This class will query all data from the model on load, due to the way
    GtkTreeView works, so you will probably want to use
    :class:`GtkTreeModelLazyShim` instead.
    '''

    class IterData:
        # Would be nice to have separate terminology for the following
        # things:
        #   - offset of row relative to page       (offset?)
        #   - offset of page relative to container (offset?)
        #   - offset of row relative to container  (row_n?)
        def __init__(self, container, page, row_offset):
            self.container = container
            self.page = page
            self.row_offset = row_offset

    def __init__(self, data):
        super(GtkTreeModelBasicShim, self).__init__()

        self.data = data

        self._next_iter_id = 1
        self._iter_data = dict()
        self._invalidate_iters()

    def _get_iter_data(self, iter):
        return self._iter_data[iter.user_data]

    def _create_iter(self, *args):
        iter = Gtk.TreeIter()
        iter.user_data = self._next_iter_id
        self._next_iter_id += 1
        self._iter_data[iter.user_data] = self.IterData(*args)
        return iter

    def _unpack_iter(self, iter):
        iter_data = self._get_iter_data(iter)
        return iter_data.container, iter_data.page, iter_data.row_offset

    def _invalidate_iter(self, iter):
        del self._iter_data[iter.user_data]
        iter.user_data = 0xdeadbeef

    def _invalidate_iters(self):
        self.stamp = random.randint(-2147483648, 2147483647)
        self._iter_data.clear()

    def do_get_flags(self):
        # If you find yourself invalidating iters after a signal is
        # emitted, remove the ITERS_PERSIST flag !!
        return Gtk.TreeModelFlags.ITERS_PERSIST | Gtk.TreeModelFlags.LIST_ONLY

    def do_get_n_columns(self):
        return len(self.data.columns())

    def do_get_column_type(self, index):
        return str

    def _iter_nth_child(self, iter, n):
        assert iter is None
        container = self.data
        if n < container.page_size:
            page = container.first_page()
            row_offset = n
        else:
            rough_position = n / container.estimate_row_count()
            page = container.get_page_for_position(rough_position)
            row_offset = n % container.page_size
            if page:
                print("Got page at offset %i for rough position %f, n %i offset %i" % (page.offset, rough_position, n, row_offset))
        if page is None or row_offset >= len(page._rows):
            print("No page for n %i" % n)
            return None
        return self._create_iter(container, page, row_offset)

    def _iter_next(self, iter):
        container, page, row_offset = self._unpack_iter(iter)
        iter_data = self._get_iter_data(iter)
        if row_offset + 1 < len(page._rows):
            iter_data.row_offset += 1
        else:
            iter_data.page = container.next_page(prev_page=page)
            iter_data.row_offset = 0
            if iter_data.page is None:
                self._invalidate_iter(iter)
                iter = None
        return iter

    def _get_value(self, iter, column):
        iter_data = self._get_iter_data(iter)
        row = iter_data.page.row(iter_data.row_offset)
        return row.values[column]

    def do_get_iter(self, path):
        assert path.get_depth() == 1

        iter = None
        for i in path.get_indices():
            iter = self._iter_nth_child(iter, i)
        return (iter is not None, iter)

    def do_get_path(self, iter):
        if iter is None:
            path = Gtk.TreePath.new_first()
        else:
            path = Gtk.TreePath()
            for i in range(0, 1):
                container, page, row_offset = self._unpack_iter(iter)
                path.prepend_index(row_offset + page.offset)
        return path

    def do_get_value(self, iter, column):
        return self._get_value(iter, column)

    def do_iter_next(self, iter):
        return self._iter_next(iter)

    def do_iter_previous(self, iter):
        raise NotImplementedError()

    def do_iter_children(self, iter):
        raise NotImplementedError()

    def do_iter_has_child(self, iter):
        return True if iter is None else False

    def do_iter_n_children(self, iter):
        raise NotImplementedError()

    def do_iter_nth_child(self, parent_iter, n):
        iter = self._iter_nth_child(parent_iter, n)
        return (iter is not None), iter

    def do_iter_parent(self, child_iter):
        raise NotImplementedError()


# NOTE NOTE NOTE!
# Due to https://bugzilla.gnome.org/show_bug.cgi?id=700092 you cannot directly
# override the do_*() methods from the base class. Move the functionality into
# an internal method and then override that.


class GtkTreeModelLazyShim(GtkTreeModelBasicShim):
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

    Practical implications are:
      - gtk_tree_model_iter_nth_child() may not return exactly the nth child,
        and may not return the same row if called twice with the same n (which
        is true of any GtkTreeModel if the underlying data changes).
      - numbers in a GtkTreePath may not be accurate and two calls to
        gtk_tree_model_get_iter() may not return the same row for the same path.
        Again, this is already true if your underlying data model changes.
      - GtkTreeRowReference() works just as with any GtkTreeModel
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

    class IterData(GtkTreeModelBasicShim.IterData):
        def __init__(self, *args):
            super(GtkTreeModelLazyShim.IterData, self).__init__(*args)
            # 'anchor' row is absolute row number if the iter is normal, or
            # the location where the iter became loose if the iter is loose.
            # FIXME: track absolute row_n in the basic iter type instead
            # of row_offset.
            self.anchor_row_n = 0
            self.loose_row_n = None

    #def __init__(self, data):
    #    super(GtkTreeModelLazyShim, self).__init__(data)

    #def do_get_flags(self):
    # FIXME: override and don't set ITERS_PERSIST, I don't think it'll be
    # true once you start adding and removing rows!

    def _iter_next(self, iter):
        iter_data = self._get_iter_data(iter)

        if iter_data.loose_row_n is not None:
            iter_data.loose_row_n += 1
            if iter_data.loose_row_n >= self.data.estimate_row_count():
                self._invalidate_iter(iter)
                iter = None
        else:
            iter = super(GtkTreeModelLazyShim, self)._iter_next(iter)

            if iter is not None:
                iter_data.anchor_row_n += 1
                if iter_data.anchor_row_n >= self.data.page_size * 1.5:
                    # Set the iter loose, it's travelled too far!
                    print("Set loose iter %s at row %i" % (iter, iter_data.anchor_row_n))
                    iter_data.loose_row_n = iter_data.anchor_row_n

        return iter


test_queries = [
    dict(query=
        "SELECT ?class ?property {"
        "   ?class a rdfs:Class ."
        "   ?property a rdf:Property ; "
        "       rdfs:domain ?class"
        "} ORDER BY ?class ?property",
        root_term="class", root_pattern="?class a rdfs:Class"),
]



# Test inserting and removing data from Tracker!
# Add some contacts, since you don't use those ;)

