/*  Charango
 *  Copyright 2011 Sam Thursfield <ssssam@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Charango.Entity: a data 'object'
 * 
 * More precisely, a #Charango.Entity is an instance of an rdfs:Class.
 */
public class Charango.Entity: GLib.Object {

/* In old Entry, we used to index properties with an int. Is that practical here?
 * IF entries were only one class we could use a sort of hashmap and speed things
 * up with that .. we certainly don't want a hash table lookup on every god damn
 * line of every view refresh ...
 */
/* The problem then is that there can be more than one class. While ontologies are
 * fixed, we can use the class heirarchy to find all possible predicates and index
 * them BY class. If we change the heirarchy at run time, no matter because this is
 * all just shortcuts anyway. Restart. The problem is when we can have an Entity
 * which is an instance of more than one class heirarchy.
 *
 * I'm leaning towards just not allowing this.
 */

public Entity (Context  context,
               string   class_uri_string) {
	Charango.Class rdfs_class;

	try {
		rdfs_class = context.get_class_by_uri_string (class_uri_string);
	}
		catch (ParseError e) {
			warning ("%s", e.message);
			return;
		}

	rdfs_class.dump ();
	rdfs_class.dump_heirarchy ();
	rdfs_class.dump_properties ();
}

/* We can have slow (string arc names) and fast (indexed arc names) now. Names? */
public void set_string (string predicate,
                        string object) {
	
}

public void set_string_indexed (int    predicate_index,
                                string object) {
	
}

public void dump () {
}

}
