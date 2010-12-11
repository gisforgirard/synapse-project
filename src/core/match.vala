/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  public enum MatchType
  {
    UNKNOWN = 0,
    APPLICATION,
    GENERIC_URI,
    ACTION
  }

  public interface Match: Object
  {
    public enum Score
    {
      INCREMENT_MINOR = 2,
      INCREMENT_SMALL = 5,
      INCREMENT_MEDIUM = 10,
      INCREMENT_LARGE = 20,
      URI_PENALTY = 15,

      POOR = 50,
      BELOW_AVERAGE = 60,
      AVERAGE = 70,
      ABOVE_AVERAGE = 75,
      GOOD = 80,
      VERY_GOOD = 85,
      EXCELLENT = 90,

      HIGHEST = 100
    }
    
    // properties
    public abstract string title { get; construct set; }
    public abstract string description { get; set; }
    public abstract string icon_name { get; construct set; }
    public abstract bool has_thumbnail { get; construct set; }
    public abstract string thumbnail_path { get; construct set; }
    public abstract MatchType match_type { get; construct set; }

    public virtual void execute (Match? match)
    {
      warning ("%s.execute () is not implemented", this.get_type ().name ());
    }
    
    public signal void executed ();
  }
  
  public interface ApplicationMatch: Match
  {
    public abstract AppInfo? app_info { get; set; }
    public abstract bool needs_terminal { get; set; }
    public abstract string? filename { get; construct set; }
  }

  public interface UriMatch: Match
  {
    public abstract string uri { get; set; }
    public abstract QueryFlags file_type { get; set; }
    public abstract string mime_type { get; set; }
  }

  public interface ExtendedInfo: Match
  {
    public abstract string? extended_info { get; set; }
  }

  public class DefaultMatch: Object, Match
  {
    public string title { get; construct set; }
    public string description { get; set; }
    public string icon_name { get; construct set; }
    public bool has_thumbnail { get; construct set; }
    public string thumbnail_path { get; construct set; }
    public MatchType match_type { get; construct set; }
    
    public DefaultMatch (string query_string)
    {
      Object (title: query_string, description: "", has_thumbnail: false,
              icon_name: "unknown", match_type: MatchType.UNKNOWN);
    }
  }
}
