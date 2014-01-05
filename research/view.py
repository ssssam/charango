# Charango view experiment, 2013 edition
# Python 3!

# Weird issues:
#  - Does not work in fixed height mode due to
#    https://bugzilla.gnome.org/show_bug.cgi?id=721597

# Steps to prototype:
#  - adding & removing
#      -> adding is OK, next test removing!
#      -> then test changed, and then make automated tests!
#     how would the automated tests look? basically check that:
#     - row-inserted / row-deleted / row-changed was emitted for the correct row
#     - can you split pages up at all ? yes, of course ... just invalidate iterators,
#       and split it out! you have to renumber the offset of all subsequent pages anyway!
#       so, do a test with at least 3 pages and check that
#         - pages don't exeed max-page-size
#         - pages disappear when they have no rows left
#         - pages are renumbered appropriately!
#  - you're having a bad time with Tracker because you don't check and adjust
#    the estimation on further page reads. Recalc after every page read?
#  - also needs to try and find the end straight away
#  - test data sources:
#     incrementing numbers,
#     a prime numbers one,
#     one that adds and removes regularly
#  - app with Tracker query on one side and list of results on other
#  - GraphUpdated watching for Tracker ... that's a lot of work, it turns out!

# Automated tests:
# * test basic API with numbers source
# - test caching level with numbers source ?
# - now, you need an awkward source that estimates that it has twice as much
#   data as it has and stuff like that.
# * Add lazy model to GtkTreeView with & without fixed height & fixed widths,
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
import math
import random
import re
import sys
import weakref


class Signal(object):
    '''
    Adapted from: http://code.activestate.com/recipes/576477-yet-another-signalslot-implementation-in-python/

    Why does the Python standard library not provide this??
    '''
    def __init__(self):
        self.__slots = weakref.WeakValueDictionary()

    def __call__(self, *args, **kargs):
        for key in self.__slots:
            func, _ = key
            func(self.__slots[key], *args, **kargs)

    def connect(self, slot):
        key = (slot.__func__, id(slot.__self__))
        self.__slots[key] = slot.__self__

    def disconnect(self, slot):
        key = (slot.__func__, id(slot.__self__))
        if key in self.__slots:
            self.__slots.pop(key)

    def clear(self):
        self.__slots.clear()


class Row():
    '''
    Base class single row in a Charango model.

    Currently we assume all rows are leaf rows (no children). When extending
    Charango to display trees as well as just lists, this class should probably
    start to implement PagedDataInterface.
    '''
    def __init__(self, values):
        self.values = values


class Page():
    '''
    A page of data.

    The data within a page is not subject to change unless the underlying data
    changes.
    '''

    def __init__(self, offset=None, rows=None):
        assert isinstance(offset, int)
        self.offset = offset

        # FIXME: Make this a GSequence, perhaps
        self._rows = rows or []

    def __repr__(self):
        return "<Page %x offset %i, %i rows>" % (id(self), self.offset, len(self._rows))

    def row(self, n):
        return self._rows[n]


class PagedDataInterface():
    '''
    Lazy data model.

    The API is designed to encourage querying one page at a time, to support
    views of very large or very slow data sources. Iterating through all pages
    may be very slow!

    Although data sources often provide a row-by-row interface, this is usually
    an abstraction built upon a buffer in the data source. It would be better
    for us if the data source would expose a paged interface so that we could
    reuse the buffers inside the data source, instead of having to do our own,
    additional paging.
    '''

    def __init__(self):
        self.row_inserted = Signal()

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
        raise NotImplementedError()

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
        raise NotImplementedError()


class PagedData(PagedDataInterface):
    '''
    Base class on top of the abstract interface which provides some helpers.

    This base class is useful to any data source which is not just a simple
    wrapper on top of an existing list of values.
    '''
    def __init__(self):
        super(PagedData, self).__init__()

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
            prev_page = prev_page or self._pages[index_after-1]
            assert page.offset >= prev_page.offset + len(prev_page._rows)
        if index_after < len(self._pages):
            next_page = self._pages[index_after]
            assert page.offset + len(page._rows) <= next_page.offset
        self._pages.insert(index_after, page)
        print("store %s before %i (total %i)" % (page, index_after, len(self._pages)))

    def _read_and_store_page(self, offset, prev_page=None):
        '''
        '''
        raise NotImplementedError()

    def next_page(self, prev_page=None):
        if prev_page:
            assert prev_page in self._pages
            expected_offset = prev_page.offset + len(prev_page._rows)
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
        assert 0.0 <= position <= 1.0

        n_rows = self.estimate_row_count()
        if n_rows == 0:
            return None
        estimated_start_row_n = int(position * n_rows)

        page = None
        for page in self._pages:
            page_start = page.offset
            page_end = page_start + len(page._rows)
            if page_start <= estimated_start_row_n < page_end:
                break
        else:
            prev_page = page
            page = self._read_and_store_page(estimated_start_row_n, prev_page=prev_page)

        return page

    def _find_row(self, target_value, key_func):
        n_rows = self.estimate_row_count()
        if n_rows == 0:
            return None, None, 0

        range_min=0
        range_max=n_rows

        page_range = list(self._pages)
        while True:
            search_n = math.floor((range_max - range_min) / 2) + range_min
            assert range_min <= search_n < range_max
            # FIXME: could be cleverer about searching for the page!
            page = None
            for page in page_range:
                if page.offset <= search_n < page.offset + len(page._rows):
                    break
                if page.offset > search_n:
                    # This could happen in the Tracker source; at that point
                    # you'd need to query the page for search_n and carry
                    # on. At which point your range may have changed, of
                    # course!
                    raise AssertionError("Not all pages in memory!")
            else:
                return None, None, 0
            row = page.row(search_n - page.offset)
            found_value = key_func(row)
            print("Cmp@%i[%i-%i] %s to target %s" % (search_n, range_min, range_max, target_value, found_value))
            if found_value == target_value:
                return row, page, search_n
            elif found_value > target_value:
                range_max = search_n
                if range_min == range_max:
                    return None, page, search_n
                page_range = page_range[:page_range.index(page)+1]
            elif found_value < target_value:
                range_min = search_n + 1
                if range_min == range_max:
                    return None, page, search_n + 1
                page_range = page_range[page_range.index(page):]


            assert len(page_range) > 0

    def _insert_row(self, page, row, index_after):
        page._rows.insert(index_after, row)
        self.row_inserted(page, index_after)


class ListSource(PagedData):
    '''
    Simple data source that wraps an existing Python list.

    It's not possible to lazily wrap generators because they don't allow random
    access, so we can't usefully provide a random access view without reading
    the whole thing straight away.
    '''
    def __init__(self, value_list, page_size):
        super(ListSource, self).__init__()
        self.page_size = page_size

        def make_row(value):
            return Row([value])

        def make_pages(value_list, page_size):
            for offset in range(0, len(value_list), page_size):
                rows = map(make_row, value_list[offset:offset+page_size])
                yield Page(offset, list(rows))
        self._n_rows = len(value_list)
        self._pages = list(make_pages(value_list, page_size))

    def columns(self):
        return ["Value"]

    def estimate_row_count(self):
        return self._n_rows

    def _read_and_store_page(self, offset, prev_page=None):
        # FIXME: maybe rename this to 'read_next_page' so it's clear that
        # if you read all your pages up front you can just return None.
        return None


class LiveListSource(ListSource):
    '''
    Class which adds and removes numbers at random.
    '''
    def __init__(self, max_page_size, max_n_rows, initial_value_list = [], order='random'):
        super(LiveListSource, self).__init__(
            value_list=initial_value_list, page_size=max_page_size)
        self.max_page_size = max_page_size
        self.max_n_rows = max_n_rows
        self.random = random.Random()

        assert order in ['random', 'descending']
        self.order = order

    def columns(self):
        return ['Value']

    def estimate_row_count(self):
        print(" - estimate_row_count(): %i" % self._n_rows)
        return self._n_rows

    def _read_and_store_page(self, offset, prev_page=None):
        # Model begins empty.
        return None

    def add_row(self):
        '''
        Add a new row from the sequence.
        '''
        if self.order == 'descending':
            n = self.max_n_rows - self._n_rows - 1
        elif self.order == 'random':
            n = self.random.randrange(0, self.max_n_rows)

        if len(self._pages) == 0:
            page = Page(0)
            self._pages = [page]
            position = 0
            existing_row = None
        else:
            def key_func(row): return row.values[0]
            existing_row, page, position = self._find_row(n, key_func)

        if existing_row is None:
            print("Insert row %i at position %i" % (n, position))
            row = Row([n])
            if page is None:
                assert position == 0
            else:
                self._insert_row(page, row, position)
            self._n_rows += 1
            print("Page is: %s" % [r.values[0] for r in page._rows])
        else:
            print("Row %i already existed at %i" % (n, position))
        return True


class TrackerQuery(PagedData):
    '''
    This model provides a paged data model from a Tracker query.

    Paged internally, using OFFSET and LIMIT, which gives the following
    benefits:
       - expensive (slow) queries do not slow down the view too much
       - memory use can be kept low, if required
       - huge amounts of data can be viewed.
    '''

    # Live updates: are really half of why this shit is cool, but will also
    # be hard! Basically all Tracker gives you is:
    #
    #   GraphUpdated(delete/insert, graph id, subject id, predicate id, object id)
    #    - https://wiki.gnome.org/Projects/Tracker/Documentation/SignalsOnChanges
    #
    # You have a list of data bearing very little relation to this list of ids!
    # Still, you *can* get the IDs of each resource involved in each row of the
    # graph "just" by modifying the query to include id(?xx) for each object.
    #
    # It may be just as easy to just drop all pages in memory and re-query the
    # visible one. What happens to your estimated row count? Re-estimate, I
    # guess. Need to do performance/complexity comparison with the above
    # approach of scanning the pages in memory for the object that was deleted
    # and removing all the rows that contained it. So complex though, you
    # might need to re-sort and everything ... 
    #
    # See also the QtSparqlTracker live model:
    #   http://perezdecastro.org/2011/live-is-live-tracker-qt-uptodate.html
    #   https://maemo.gitorious.org/maemo-af/libqtsparql-tracker/source/c8843a67d56684024b132a92658b72bca5aadc70:src/live

    def __init__(self, connection, query, root_term, root_pattern,
                 read_size=100):
        '''
        Finding ``root_term`` and ``root_pattern`` could be done automatically
        by parsing ``query``, but that's too much effort for now.

        The 'read_size' parameter would ideally match the viewport size of
        whatever is displaying the data.

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
        self.read_size = 100

        super(TrackerQuery, self).__init__()

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
        cursor = self._run_query(offset=offset, limit=self.read_size)

        def find_column(cursor, variable_name):
            n_columns = cursor.get_property('n-columns')
            for i in range(0, n_columns):
                if cursor.get_variable_name(i) == variable_name:
                    return i
            raise KeyError("Did not find %s in query results." % variable_name)

        root_column = find_column(cursor, self.root_term)

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

            rows.append(Row(page_row_n, values))
            page_row_n += 1

        # FIXME: if last page, set a flag? Is there a way to spot the last
        # page if it happens to finish at LIMIT rows?

        if len(rows) == 0:
            return None

        page = Page(offset, rows)
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
            print ("%s(%s)" % (method.__name__, ', '.join(p_args)), end='')
            result = method(*args, **kwargs)
            print (" -> %s" % str(result))
            return result
        return wrapper

    def __new__(cls, classname, bases, classdict):
        for name, value in list(classdict.items()):
            if inspect.isfunction(value) and name.startswith('do_'):
                classdict['_GInterfaceTraceMetaclass_%s' % name] = value
                classdict[name] = GInterfaceTraceMetaclass._trace_call(value)
        return type.__new__(cls,classname,bases,classdict)


class GtkTreeModelBasicShim(GObject.Object, Gtk.TreeModel,#):
                            metaclass=GInterfaceTraceMetaclass):
    '''
    Basic GtkTreeView adapter for paged data models.

    This class will query all data from the model on load, due to the way
    GtkTreeView works, so you will probably want to use
    :class:`GtkTreeModelLazyShim` instead.
    '''

    __gtype_name__ = 'GtkTreeModelBasicShim'

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
        self.data.row_inserted.connect(self.handle_row_inserted)

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
        n_rows = container.estimate_row_count()
        if n_rows == 0:
            return None
        rough_position = n / n_rows
        page = container.get_page_for_position(rough_position)
        # FIXME: this method is great expect where you have a big source and you're on the
        # boundry of a page. You'll need to go up or down a page or two to actually find
        # the one that contains 'n', presumably ... and in doing so you'll read more data,
        # which may change the estimation, so it needs to be done in a loop BUT that's OK!
        row_offset = n - page.offset
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
            container, page, row_offset = self._unpack_iter(iter)
            path = Gtk.TreePath(path=row_offset)
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

    def handle_row_inserted(self, page, row_offset):
        path = Gtk.TreePath(page.offset + row_offset)
        iter = self._create_iter(self.data, page, row_offset)
        print("Row-inserted: %s, %s (%s)" % (path, iter, self._get_iter_data(iter).__dict__))
        #self.emit('row-inserted', path, iter)
        self.row_inserted(path, iter)


# NOTE NOTE NOTE!
# Due to https://bugzilla.gnome.org/show_bug.cgi?id=700092 you cannot directly
# override the do_*() methods from the base class. Move the functionality into
# an internal method and then override that.


# FIXME: rename to GtkTreeViewLazyShim ?? it violates MVC completely :)
class GtkTreeModelLazyShim(GtkTreeModelBasicShim):
    '''
    Adapt GtkTreeView to do lazy querying of the underlying data model.

    GtkTreeView attempts to touch every row in the GtkTreeModel on load, to
    calculate its a size, which forces reading the whole of potentially huge,
    slow data source. To work around this, GtkTreeModelLazyShim takes a
    'viewport_n_rows' parameter, which specifies the maximum number of rows of
    data visible on screen. After a single iterator has queried at least enough
    rows to be displayed, it will become 'loose' and no longer return data from
    the underlying model.

    Theoretically we could calculate 'viewport_n_rows based' on the size
    request of the GtkTreeView's container (usually a GtkScrolledWindow), but
    in practice since screen sizes are limited you can probably just pick a big
    number and get on with your day.

    Practical implications are:
      - gtk_tree_model_iter_nth_child() may not return exactly the nth child,
        and may not return the same row if called twice with the same n (which
        is true of any GtkTreeModel if the underlying data changes).
      - numbers in a GtkTreePath may not be accurate and two calls to
        gtk_tree_model_get_iter() may not return the same row for the same path.
        Again, this is already true if your underlying data model changes.
      - GtkTreeRowReference() works just as with any GtkTreeModel
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

    def __init__(self, data, viewport_n_rows):
        super(GtkTreeModelLazyShim, self).__init__(data)
        self.viewport_n_rows = viewport_n_rows

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
                if iter_data.anchor_row_n >= int(self.viewport_n_rows * 1.5):
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

