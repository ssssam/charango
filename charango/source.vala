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

/* Notify code:

	queue_removal_if_notifying() - pushes to removal queue if the notify
            flag is set, or returns FALSE
	queue_checkin_if_notifying()

	add_entry()  => cannot be called during notify (need to return ID so can't defer exec)
	remove_entry() => (defers if notifying)
	checkout_entry() => all cool
	checkin_entry() => (defers if notifying - so only one tree of objects gets committed in
                            one transaction)
	update_entry_property() => convenience func
*/

/* Editing code:

	The tree of related entries gets checked out and a copy is returned to the caller.
	It's like an SVN working tree - especially in that merges are impossible. On checkin,
	the whole tree is notified upon and then any queued changes are executed as a new
	transaction. One checkout/checkin = one transaction!

	Merging - this is RDF's problem now :)
*/

}
