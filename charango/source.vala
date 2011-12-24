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


public interface Charango.Source {

/**
 * list_all_resources
 * @type: class of resource to return.
 * @limit: suggested batch size
 *
 * Backends should always honour @limit, but it is not required - be aware
 * that you may be returned more results than you requested.
 *
 * Depending on the source and the size of the dataset, this operation may be
 * very slow! Use the batch size option sensibly, and never block waiting for
 * data in your UI thread!
 *
 * Remember that all resources have type rdfs:Resource. Most resources have
 * more than one type.
 */
public abstract List<unowned Charango.Entity> list_resources (Charango.Class type,
                                                              uint           limit);

/**
 * find_resource():
 * @type: type of resource to return
 * @uri: resource identifier string. Key URIs are allowed.
 *
 * Locates the given entity of the correct type inside the current namespace.
 * Remember that all resources have type rdfs:Resource, so you can use this
 * type to search all resources in the namespace.
 *
 * Returns %NULL if the resource could not be found.
 */
public abstract Charango.Entity? find_resource (Charango.Class type,
                                                string         uri);


/*public struct ResourceChange {
	Charango.Entity? old_resource;
	Charango.Entity? new_resource;
}

public delegate void WatchFunc (List<ResourceChange> change_list);

public delegate void ResourceWatchFunc (Charango.Entity? old_state,
                                        Charango.Entity? new_state);

public struct WatchClosure {
	unowned Charango.Source source;
	WatchFunc callback;
}

public struct ResourceWatchClosure {
	unowned Charango.Source source;
	Charango.Class type;
	ResourceWatchFunc callback;
}

public WatchClosure connect_watch (WatchFunc callback) {
	WatchClosure closure = WatchClosure ();
	closure.callback = callback;

	return closure;
}

public ResourceWatchClosure connect_resource_watch (Charango.Class type,
                                                    ResourceWatchFunc callback) {
	ResourceWatchClosure closure = ResourceWatchClosure ();
	closure.type = type;
	closure.callback = callback;

	return closure;
}
*/

/* Missing API from old MusicSource API (to add when needed):
	get_n_entries(type) => get n resources of a class
	is_valid_id(id) => shouldn't need? this is to check for dead id's

	query_entry (type, id) => query by ID

	query_relations (local_type, local_id, relation_apid)
		=> basically - given subject and object, get predicates,
                   or vice versa

	also query_n_relations ()
*/

}
