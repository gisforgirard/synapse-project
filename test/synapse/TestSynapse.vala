/*
 * Copyright (c) 2021 Payson Wallach <payson@paysonwallach.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

int main (string[] args) {
    Gtk.init (ref args);
    Test.init (ref args);

    var retval = -1;
    var root = TestSuite.get_root ();

    root.add_suite (
        new Synapse.TestQueryHistory ().suite);

    Idle.add (() => {
        retval = Test.run ();
        Gtk.main_quit ();
        return false;
    });

    Gtk.main ();

    return retval;
}
