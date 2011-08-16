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

using Rdf;

/* These are really programmer errors rather than runtime exceptions,
 * because the ontologies are of course API. However, using exceptions
 * simplifies the error checking.
 */
public errordomain Charango.ParseError {
	PARSE_ERROR,
	INDEX_PARSE_ERROR,
	INVALID_URI,
	DUPLICATE_DEFINITION,
	MISSING_DEFINITION,
	UNKNOWN_NAMESPACE,

	/* This one isn't an error at all, but it seems like the cleanest solution
	 * to how to handle ignored namespaces. */
	IGNORED_NAMESPACE
}

/* FIXME: some parse errors should be in here */
public errordomain Charango.OntologyError {
	UNKNOWN_RESOURCE,
	UNKNOWN_CLASS,
	UNKNOWN_PROPERTY,  /* Subject outside property domain */
	TYPE_MISMATCH,     /* Object outside property range */
	INVALID_DEFINITION,
	INTERNAL_ERROR
}

/**
 * Charango.Warning:
 * 
 * Returned by some parse methods when non-fatal errors are discovered while
 * parsing. The caller may choose to ignore these or alert the user.
 */
[Compact]
public class Charango.Warning {
	public string message;

	public Warning (string _message,
	                ...) {
		var va = va_list();
		message = _message.vprintf (va);
	}
}

namespace Charango {

internal void glib_logger (string?            domain,
                           GLib.LogLevelFlags log_level,
                           string             message) {
	/* Handles only Charango debug messages */
	for (uint i=(log_level>>8); i>0; i>>=1)
		printerr ("  ");
	printerr (message);
}

internal int redland_logger (LogMessage message) {
	const GLib.LogLevelFlags log_level_mapping[] = {
		0,
		GLib.LogLevelFlags.LEVEL_DEBUG,
		GLib.LogLevelFlags.LEVEL_INFO,
		GLib.LogLevelFlags.LEVEL_WARNING,
		GLib.LogLevelFlags.LEVEL_ERROR,
		GLib.LogLevelFlags.LEVEL_CRITICAL
	};

	StringBuilder output = new StringBuilder ();

	if (message.locator != null) {
		string file = message.locator.file ?? message.locator.uri.as_string();
		output.append_printf ("%s:%i: ", file, message.locator.line);
	}

	output.append (message.message);

	GLib.log ("Charango", log_level_mapping[message.level], output.str);

	return 1;
}

/* FIXME: ideally, we would make it possible to disable tracing via a #ifdef,
 * this is something that perhaps could be directly built into vala ... */
internal void trace (string component,
                     string format, ...) {
	va_list va = va_list();
	tracev (0, component, format, va);
}

internal void tracel (int    level,
                      string component,
                      string format, ...) {
	va_list va = va_list();
	tracev (level, component, format, va);
}

private void tracev (int    level,
                     string component,
                     string format, va_list va) {
	return;  // Comment me out to get some traces!

	logv ("Charango", (GLib.LogLevelFlags)(1<<level) << 8, format, va);
}

public void print_warnings (List<Warning> warning_list) {
	foreach (unowned Warning w in warning_list)
		print ("Warning: %s\n", w.message);
}

}
