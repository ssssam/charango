import view

'''
Charango is a way of displaying large, sequentially-access data sources for
human consumption. In particular it's a way of displaying the results of
Tracker queries in a GtkTreeView.
'''

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


class SimpleMockDataSource(view.PagedDataInterface):
    '''
    Data source usable for testing.
    '''
    def __init__(self, rows, page_size=None):
        self._rows = rows
        self._pages = []
        super(SimpleMockDataSource, self).__init__(page_size=page_size)

    def _estimate_row_count(self):
        return len(self._rows)

    def _read_and_store_page(self, offset, prev_page):
        page = view.Page(offset)
        for i, value in enumerate(self._rows[offset:offset + self.page_size]):
            row = view.Row(page, i, value)
            page.append_row(row) 
        self._store_page(page)
        return page


class TestPagedData():
    '''
    Test the PagedDataInterface model using a simple mock data source.
    '''
    def test_simple(self):
        '''
        '''
        data = SimpleMockDataSource(range(100), page_size=10)

        assert data._estimated_n_rows == 100

        first_page = data.first_page()

        # Need to ... have 10 pages, query the row of page 5, but have page 3 and 4 be tiny so
        # lots of row changes occur .... OK!

        # how do you actually emit the row changes?
        # estimation-changed signal ... BUT then every row needs to be a GObject! That's not so
        # nice. Not at all!
