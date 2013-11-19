import view

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


class SimpleMockDataSource(view.CharangoPagedData):
    '''
    Data source usable for testing.
    '''
    def __init__(self, rows, page_size=None):
        super(MockDataSource, self).__init__(page_size=page_size)
        self.rows = rows

    def _estimate_row_n_children(self, row):
        # This is a list, not a tree ... no nesting.
        assert row == self._root_row

        return len(self.rows)


class TestPagedData():
    def test_simple(self):
        '''
        '''
        data = SimpleMockDataSource(range(100), page_size=10)

        root_row = data.get_root()
        assert root_row._estimated_n_children == 100

        first_page = root_row.next_page()

        # Need to ... have 10 pages, query the row of page 5, but have page 3 and 4 be tiny so
        # lots of row changes occur .... OK!

        # how do you actually emit the row changes?
        # estimation-changed signal ... BUT then every row needs to be a GObject! That's not so
        # nice. Not at all!
