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


class MockDataSource(CharangoPagedData):
    '''
    Data source usable for testing.
    '''
    pass


class TestPagedData():
    def test_simple(self):
        '''
        '''
        # Need to ... have 10 pages, query the row of page 5, but have page 3 and 4 be tiny so
        # lots of row changes occur .... OK!

        # how do you actually emit the row changes?
        # estimation-changed signal ... BUT then every row needs to be a GObject! That's not so
        # nice. Not at all!
