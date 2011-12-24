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

/* Simple object store implementation.
 *
 * FIXME: there are probably some efficiency gains to be made ;)
 */

public class Charango.MemoryStore: Store {

private HashTable<Charango.Class,List<Charango.Entity>> data;

public MemoryStore () {
	this.data = new GLib.HashTable<Charango.Class,List<Charango.Entity>> (direct_hash, direct_equal);
}

public List<unowned Charango.Entity> list_resources (Charango.Class type,
                                                     uint           limit) {
	/* FIXME: limit is not honoured */
	return this.data.lookup(type).copy();
}

public abstract Charango.Entity find_resource (Charango.Class type,
                                               string         uri) {
	var entity_list = this.data.lookup (type);

	foreach (Charango.Entity e in entity_list)
		if (e.uri == uri || e.key_uri == uri)
			return e;

	return null;
}

}
