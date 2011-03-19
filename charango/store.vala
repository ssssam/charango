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

using GLib;

/**
 * Charango.Store: data model base class
 */
public class Charango.Store: GLib.Object {

/*List entry_notify_handlers = null;
List transaction_notify_handlers = null;
List transaction_change_list = null;*/

Mutex queues_lock = new Mutex();
List checkin_queue = null;
List removal_queue = null;

/*bool in_notify;*/

//List<Class> class_list = null;

public Store() {
}

~Store() {
	if (queues_lock.trylock())
		queues_lock.unlock ();
	else
		warning ("store %lx: finalised while queues lock held.\n",
		         (ulong)queues_lock);
}

}
