/*
* Copyright (c) 2009-2013 Yorba Foundation
*               2017 elementary  LLC. (https://launchpad.net/pantheon-photos)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class ExportDialog : Gtk.Dialog {
    public const int DEFAULT_SCALE = 1200;

    // "Unmodified" and "Current," though they appear in the "Format:" popup menu, really
    // aren't formats so much as they are operating modes that determine specific formats.
    // Hereafter we'll refer to these as "special formats."
    public const int NUM_SPECIAL_FORMATS = 2;
    public const string UNMODIFIED_FORMAT_LABEL = _ ("Unmodified");
    public const string CURRENT_FORMAT_LABEL = _ ("Current");

    public const ScaleConstraint[] CONSTRAINT_ARRAY = { ScaleConstraint.ORIGINAL,
                                                        ScaleConstraint.DIMENSIONS, ScaleConstraint.WIDTH, ScaleConstraint.HEIGHT
                                                      };

    public const Jpeg.Quality[] QUALITY_ARRAY = { Jpeg.Quality.LOW, Jpeg.Quality.MEDIUM,
                                                  Jpeg.Quality.HIGH, Jpeg.Quality.MAXIMUM
                                                };

    private static ScaleConstraint current_constraint = ScaleConstraint.ORIGINAL;
    private static ExportFormatParameters current_parameters = ExportFormatParameters.current ();
    private static int current_scale = DEFAULT_SCALE;

    private Gtk.Grid table = new Gtk.Grid ();
    private Gtk.ComboBoxText quality_combo;
    private Gtk.ComboBoxText constraint_combo;
    private Gtk.ComboBoxText format_combo;
    private Gtk.CheckButton export_metadata;
    private Gee.ArrayList<string> format_options = new Gee.ArrayList<string> ();
    private Gtk.Entry pixels_entry;
    private Gtk.Widget ok_button;
    private bool in_insert = false;

    public ExportDialog (string title) {
        this.title = title;
        resizable = false;
        deletable = false;

        quality_combo = new Gtk.ComboBoxText ();
        int ctr = 0;
        foreach (Jpeg.Quality quality in QUALITY_ARRAY) {
            quality_combo.append_text (quality.to_string ());
            if (quality == current_parameters.quality)
                quality_combo.set_active (ctr);
            ctr++;
        }

        constraint_combo = new Gtk.ComboBoxText ();
        ctr = 0;
        foreach (ScaleConstraint constraint in CONSTRAINT_ARRAY) {
            constraint_combo.append_text (constraint.to_string ());
            if (constraint == current_constraint)
                constraint_combo.set_active (ctr);
            ctr++;
        }

        format_combo = new Gtk.ComboBoxText ();
        format_add_option (UNMODIFIED_FORMAT_LABEL);
        format_add_option (CURRENT_FORMAT_LABEL);
        foreach (PhotoFileFormat format in PhotoFileFormat.get_writeable ()) {
            format_add_option (format.get_properties ().get_user_visible_name ());
        }

        pixels_entry = new Gtk.Entry ();
        pixels_entry.set_max_length (6);
        pixels_entry.set_size_request (60, -1);
        pixels_entry.set_text ("%d".printf (current_scale));

        // register after preparation to avoid signals during init
        constraint_combo.changed.connect (on_constraint_changed);
        format_combo.changed.connect (on_format_changed);
        pixels_entry.changed.connect (on_pixels_changed);
        pixels_entry.insert_text.connect (on_pixels_insert_text);
        pixels_entry.activate.connect (on_activate);

        // layout controls
        add_label (_ ("_Format:"), 0, 0, format_combo);
        add_control (format_combo, 1, 0);

        add_label (_ ("_Quality:"), 0, 1, quality_combo);
        add_control (quality_combo, 1, 1);

        add_label (_ ("_Scaling constraint:"), 0, 2, constraint_combo);
        add_control (constraint_combo, 1, 2);

        Gtk.Label pixels_label = new Gtk.Label.with_mnemonic (_ (" _pixels"));
        pixels_label.set_mnemonic_widget (pixels_entry);

        Gtk.Box pixels_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        pixels_box.pack_start (pixels_entry, false, false, 0);
        pixels_box.pack_end (pixels_label, false, false, 0);
        add_control (pixels_box, 1, 3);

        export_metadata = new Gtk.CheckButton.with_label (_ ("Export metadata"));
        add_control (export_metadata, 1, 4);
        export_metadata.active = true;

        table.set_row_spacing (4);
        table.set_column_spacing (4);
        table.set_margin_top (4);
        table.set_margin_bottom (4);
        table.set_margin_start (4);
        table.set_margin_end (4);

        ((Gtk.Box) get_content_area ()).add (table);

        // add buttons to action area
        add_button (_ ("_Cancel"), Gtk.ResponseType.CANCEL);
        ok_button = add_button (_ ("_Export"), Gtk.ResponseType.OK);

        ok_button.set_can_default (true);
        ok_button.has_default = true;
        set_default (ok_button);

        if (current_constraint == ScaleConstraint.ORIGINAL) {
            pixels_entry.sensitive = false;
            quality_combo.sensitive = false;
        }

        ok_button.grab_focus ();
    }

    private void format_add_option (string format_name) {
        format_options.add (format_name);
        format_combo.append_text (format_name);
    }

    private void format_set_active_text (string text) {
        int selection_ticker = 0;

        foreach (string current_text in format_options) {
            if (current_text == text) {
                format_combo.set_active (selection_ticker);
                return;
            }
            selection_ticker++;
        }

        error ("format_set_active_text: text '%s' isn't in combo box", text);
    }

    private PhotoFileFormat get_specified_format () {
        int index = format_combo.get_active ();
        if (index < NUM_SPECIAL_FORMATS)
            index = NUM_SPECIAL_FORMATS;

        index -= NUM_SPECIAL_FORMATS;
        PhotoFileFormat[] writeable_formats = PhotoFileFormat.get_writeable ();
        return writeable_formats[index];
    }

    private string get_label_for_parameters (ExportFormatParameters params) {
        switch (params.mode) {
        case ExportFormatMode.UNMODIFIED:
            return UNMODIFIED_FORMAT_LABEL;

        case ExportFormatMode.CURRENT:
            return CURRENT_FORMAT_LABEL;

        case ExportFormatMode.SPECIFIED:
            return params.specified_format.get_properties ().get_user_visible_name ();

        default:
            error ("get_label_for_parameters: unrecognized export format mode");
        }
    }

    // unlike other parameters, which should be persisted across dialog executions, the
    // format parameters must be set each time the dialog is executed -- this is why
    // it's passed qualified as ref and not as out
    public bool execute (out int scale, out ScaleConstraint constraint,
                         ref ExportFormatParameters parameters) {
        show_all ();

        // if the export format mode isn't set to last (i.e., don't use the persisted settings),
        // reset the scale constraint to original size
        if (parameters.mode != ExportFormatMode.LAST) {
            current_constraint = constraint = ScaleConstraint.ORIGINAL;
            constraint_combo.set_active (0);
        }

        if (parameters.mode == ExportFormatMode.LAST)
            parameters = current_parameters;
        else if (parameters.mode == ExportFormatMode.SPECIFIED && !parameters.specified_format.can_write ())
            parameters.specified_format = PhotoFileFormat.get_system_default_format ();

        format_set_active_text (get_label_for_parameters (parameters));
        on_format_changed ();

        bool ok = (run () == Gtk.ResponseType.OK);
        if (ok) {
            int index = constraint_combo.get_active ();
            assert (index >= 0);
            constraint = CONSTRAINT_ARRAY[index];
            current_constraint = constraint;

            scale = int.parse (pixels_entry.get_text ());
            if (constraint != ScaleConstraint.ORIGINAL)
                assert (scale > 0);
            current_scale = scale;

            parameters.export_metadata = export_metadata.sensitive ? export_metadata.active : false;

            if (format_combo.get_active_text () == UNMODIFIED_FORMAT_LABEL) {
                parameters.mode = current_parameters.mode = ExportFormatMode.UNMODIFIED;
            } else if (format_combo.get_active_text () == CURRENT_FORMAT_LABEL) {
                parameters.mode = current_parameters.mode = ExportFormatMode.CURRENT;
            } else {
                parameters.mode = current_parameters.mode = ExportFormatMode.SPECIFIED;
                parameters.specified_format = current_parameters.specified_format = get_specified_format ();
                if (current_parameters.specified_format == PhotoFileFormat.JFIF)
                    parameters.quality = current_parameters.quality = QUALITY_ARRAY[quality_combo.get_active ()];
            }
        } else {
            scale = 0;
            constraint = ScaleConstraint.ORIGINAL;
        }

        destroy ();

        return ok;
    }

    private void add_label (string text, int x, int y, Gtk.Widget? widget = null) {
        Gtk.Alignment left_aligned = new Gtk.Alignment (0.0f, 0.5f, 0, 0);

        Gtk.Label new_label = new Gtk.Label.with_mnemonic (text);
        new_label.set_use_underline (true);

        if (widget != null)
            new_label.set_mnemonic_widget (widget);

        left_aligned.add (new_label);

        table.attach (left_aligned, x, y, 1, 1);
    }

    private void add_control (Gtk.Widget widget, int x, int y) {
        Gtk.Alignment left_aligned = new Gtk.Alignment (0, 0.5f, 0, 0);
        left_aligned.add (widget);

        table.attach (left_aligned, x, y, 1, 1);
    }

    private void on_constraint_changed () {
        bool original = CONSTRAINT_ARRAY[constraint_combo.get_active ()] == ScaleConstraint.ORIGINAL;
        bool jpeg = format_combo.get_active_text () ==
                    PhotoFileFormat.JFIF.get_properties ().get_user_visible_name ();
        pixels_entry.sensitive = !original;
        quality_combo.sensitive = !original && jpeg;
        if (original)
            ok_button.sensitive = true;
        else
            on_pixels_changed ();
    }

    private void on_format_changed () {
        bool original = CONSTRAINT_ARRAY[constraint_combo.get_active ()] == ScaleConstraint.ORIGINAL;

        if (format_combo.get_active_text () == UNMODIFIED_FORMAT_LABEL) {
            // if the user wishes to export the media unmodified, then we just copy the original
            // files, so parameterizing size, quality, etc. is impossible -- these are all
            // just as they are in the original file. In this case, we set the scale constraint to
            // original and lock out all the controls
            constraint_combo.set_active (0); /* 0 == original size */
            constraint_combo.set_sensitive (false);
            quality_combo.set_sensitive (false);
            pixels_entry.sensitive = false;
            export_metadata.active = false;
            export_metadata.sensitive = false;
        } else if (format_combo.get_active_text () == CURRENT_FORMAT_LABEL) {
            // if the user wishes to export the media in its current format, we allow sizing but
            // not JPEG quality customization, because in a batch of many photos, it's not
            // guaranteed that all of them will be JPEGs or RAWs that get converted to JPEGs. Some
            // could be PNGs, and PNG has no notion of quality. So lock out the quality control.
            // If the user wants to set JPEG quality, he or she can explicitly specify the JPEG
            // format.
            constraint_combo.set_sensitive (true);
            quality_combo.set_sensitive (false);
            pixels_entry.sensitive = !original;
            export_metadata.sensitive = true;
        } else {
            // if the user has chosen a specific format, then allow JPEG quality customization if
            // the format is JPEG and the user is re-sizing the image, otherwise, disallow JPEG
            // quality customization; always allow scaling.
            constraint_combo.set_sensitive (true);
            bool jpeg = get_specified_format () == PhotoFileFormat.JFIF;
            quality_combo.sensitive = !original && jpeg;
            export_metadata.sensitive = true;
        }
    }

    private void on_activate () {
        response (Gtk.ResponseType.OK);
    }

    private void on_pixels_changed () {
        ok_button.sensitive = (pixels_entry.get_text_length () > 0) && (int.parse (pixels_entry.get_text ()) > 0);
    }

    private void on_pixels_insert_text (string text, int length, ref int position) {
        // This is necessary because SignalHandler.block_by_func () is not properly bound
        if (in_insert)
            return;

        in_insert = true;

        if (length == -1)
            length = (int) text.length;

        // only permit numeric text
        string new_text = "";
        for (int ctr = 0; ctr < length; ctr++) {
            if (text[ctr].isdigit ()) {
                new_text += ((char) text[ctr]).to_string ();
            }
        }

        if (new_text.length > 0)
            pixels_entry.insert_text (new_text, (int) new_text.length, ref position);

        Signal.stop_emission_by_name (pixels_entry, "insert-text");

        in_insert = false;
    }
}
