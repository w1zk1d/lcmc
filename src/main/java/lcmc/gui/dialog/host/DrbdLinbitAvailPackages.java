/*
 * This file is part of DRBD Management Console by LINBIT HA-Solutions GmbH
 * written by Rasto Levrinc.
 *
 * Copyright (C) 2009, LINBIT HA-Solutions GmbH.
 * Copyright (C) 2011-2012, Rastislav Levrinc.
 *
 * DRBD Management Console is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * DRBD Management Console is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with drbd; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

package lcmc.gui.dialog.host;

import java.awt.Dimension;
import java.awt.FlowLayout;
import java.util.Arrays;
import java.util.List;

import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SpringLayout;

import lcmc.data.AccessMode;
import lcmc.data.Application;
import lcmc.data.Host;
import lcmc.data.StringValue;
import lcmc.data.Value;
import lcmc.gui.SpringUtilities;
import lcmc.gui.dialog.WizardDialog;
import lcmc.gui.widget.Widget;
import lcmc.gui.widget.WidgetFactory;
import lcmc.utilities.ExecCallback;
import lcmc.utilities.Logger;
import lcmc.utilities.LoggerFactory;
import lcmc.utilities.ssh.Ssh;
import lcmc.utilities.ssh.ExecCommandThread;
import lcmc.utilities.Tools;
import lcmc.utilities.WidgetListener;

/**
 * An implementation of a dialog where user can choose a distribution of the
 * host.
 *
 * @author Rasto Levrinc
 * @version $Id$
 *
 */
public class DrbdLinbitAvailPackages extends DialogHost {
    /** Logger. */
    private static final Logger LOG =
                      LoggerFactory.getLogger(DrbdLinbitAvailPackages.class);
    /** No match string. */
    private static final String NO_MATCH_STRING = "No Match";
    /** Newline. */
    private static final String NEWLINE = "\\r?\\n";
    /** Height of the choice boxes. */
    private static final int CHOICE_BOX_HEIGHT = 30;
    /** Combo box with distributions. */
    private Widget drbdDistCombo = null;
    /** Combo box with available kernel versions for this distribution. */
    private Widget drbdKernelDirCombo = null;
    /** Combo box with available architectures versions for this distribution.
     */
    private Widget drbdArchCombo = null;
    /** List of items in the dist combo. */
    private List<String> drbdDistItems = null;
    /** List of items in the kernel versions combo. */
    private List<String> drbdKernelDirItems = null;
    /** List of items in the arch combo. */
    private List<String> drbdArchItems = null;

    /** Prepares a new {@code DrbdLinbitAvailPackages} object. */
    public DrbdLinbitAvailPackages(final WizardDialog previousDialog,
                                   final Host host) {
        super(previousDialog, host);
    }

    /** Checks the available drbd verisions. */
    protected final void availVersions() {
        /* get drbd available versions,
         * they are independent from distribution and kernel version and
         * are first directory part in the download area.*/
        drbdDistCombo.setEnabled(false);
        drbdKernelDirCombo.setEnabled(false);
        drbdArchCombo.setEnabled(false);
        getProgressBar().start(20000);
        final ExecCommandThread t = getHost().execCommand(
                          "DrbdAvailVersions",
                          null, /* ProgressBar */
                          new ExecCallback() {
                            @Override
                            public void done(final String answer) {
                                final String[] items = answer.split(NEWLINE);
                                /* all drbd versions are stored in form
                                 * {version1,version2,...}. This will be
                                 * later expanded by shell. */
                                getHost().setDrbdVersionToInstall(
                                                        Tools.shellList(items));
                                availDistributions();
                            }
                            @Override
                            public void doneError(final String answer,
                                                  final int errorCode) {
                                printErrorAndRetry(Tools.getString(
                              "Dialog.Host.DrbdLinbitAvailPackages.NoVersions"),
                                        answer,
                                        errorCode);
                            }
                          },
                          null,   /* ConvertCmdCallback */
                          false,  /* outputVisible */
                          Ssh.DEFAULT_COMMAND_TIMEOUT);
        setCommandThread(t);
    }

    /** Checks the available distributions. */
    protected final void availDistributions() {
        Tools.invokeLater(new Runnable() {
            @Override
            public void run() {
                drbdKernelDirCombo.setEnabled(false);
                drbdArchCombo.setEnabled(false);
            }
        });
        final ExecCommandThread t = getHost().execCommand(
                          "DrbdAvailDistributions",
                          null, /* ProgressBar */
                          new ExecCallback() {
                            @Override
                            public void done(String answer) {
                                answer = NO_MATCH_STRING + '\n' + answer;
                                final String[] items = answer.split(NEWLINE);
                                drbdDistItems = Arrays.asList(items);
                                Tools.invokeLater(new Runnable() {
                                    @Override
                                    public void run() {
                                        drbdDistCombo.reloadComboBox(
                                            new StringValue(
                                                  getHost().getDistVersion()),
                                            StringValue.getValues(items));
                                        drbdDistCombo.setEnabled(true);
                                    }
                                });
                                availKernels();
                            }
                            @Override
                            public void doneError(final String answer,
                                                  final int errorCode) {
                                printErrorAndRetry(Tools.getString(
                         "Dialog.Host.DrbdLinbitAvailPackages.NoDistributions"),
                                        answer,
                                        errorCode);
                            }
                          },
                          null,   /* ConvertCmdCallback */
                          false,  /* outputVisible */
                          Ssh.DEFAULT_COMMAND_TIMEOUT);
        setCommandThread(t);
    }

    /** Checks what are the available kernels for this distribution. */
    protected final void availKernels() {
        final String distVersion = getHost().getDistVersion();
        if (drbdDistItems == null || !drbdDistItems.contains(distVersion)) {
            Tools.invokeLater(new Runnable() {
                @Override
                public void run() {
                    drbdKernelDirCombo.reloadComboBox(
                                                null,
                                                new Value[]{new StringValue(NO_MATCH_STRING)});
                }
            });
            availArchs();
            return;
        }
        final ExecCommandThread t = getHost().execCommand(
                          "DrbdAvailKernels",
                          null, /* ProgressBar */
                          new ExecCallback() {
                            @Override
                            public void done(String answer) {
                                answer = NO_MATCH_STRING + '\n' + answer;
                                final String[] items = answer.split(NEWLINE);
                                drbdKernelDirItems = Arrays.asList(items);
                                Tools.invokeLater(new Runnable() {
                                    @Override
                                    public void run() {
                                        drbdKernelDirCombo.reloadComboBox(
                                            new StringValue(
                                               getHost().getKernelVersion()),
                                            StringValue.getValues(items));
                                        drbdKernelDirCombo.setEnabled(true);
                                    }
                                });
                                availArchs();
                            }

                            @Override
                            public void doneError(final String answer,
                                                  final int errorCode) {
                                LOG.debug("doneError:");
                                printErrorAndRetry(
               Tools.getString("Dialog.Host.DrbdLinbitAvailPackages.NoKernels"),
                                        answer,
                                        errorCode);
                            }
                          },
                          null,   /* ConvertCmdCallback */
                          false,  /* outputVisible */
                          Ssh.DEFAULT_COMMAND_TIMEOUT);
        setCommandThread(t);
    }

    /** Checks what are the available architectures for this distribution. */
    protected final void availArchs() {
        final String kernelVersion = getHost().getKernelVersion();
        final String arch = getHost().getArch();
        if (drbdDistItems == null
            || drbdKernelDirItems == null
            || arch == null
            || !drbdDistItems.contains(getHost().getDistVersion())
            || !drbdKernelDirItems.contains(kernelVersion)) {
            Tools.invokeLater(new Runnable() {
                @Override
                public void run() {
                    drbdArchCombo.reloadComboBox(null,
                                                 new Value[]{new StringValue(NO_MATCH_STRING)});
                    drbdArchCombo.setEnabled(false);
                }
            });
            allDone(null);
            return;
        }
        final ExecCommandThread t = getHost().execCommand(
                          "DrbdAvailArchs",
                          null, /* ProgressBar */
                          new ExecCallback() {
                            @Override
                            public void done(String answer) {
                                answer = NO_MATCH_STRING + '\n' + answer;
                                final String[] items = answer.split(NEWLINE);
                                drbdArchItems = Arrays.asList(items);
                                Tools.invokeLater(new Runnable() {
                                    @Override
                                    public void run() {
                                        drbdArchCombo.reloadComboBox(
                                                new StringValue(arch),
                                                StringValue.getValues(items));
                                        drbdArchCombo.setEnabled(true);
                                    }
                                });
                                if (drbdArchItems == null) {
                                    allDone(null);
                                } else {
                                    availVersionsForDist();
                                }
                            }

                            @Override
                            public void doneError(final String answer,
                                                  final int errorCode) {
                                printErrorAndRetry(Tools.getString(
                                 "Dialog.Host.DrbdLinbitAvailPackages.NoArchs"),
                                        answer,
                                        errorCode);
                            }
                          },
                          null,   /* ConvertCmdCallback */
                          false,  /* outputVisible */
                          Ssh.DEFAULT_COMMAND_TIMEOUT);

        setCommandThread(t);
    }

    /** Checks what are the avail drbd versions for this distribution. */
    protected final void availVersionsForDist() {
        final ExecCommandThread t = getHost().execCommand(
                          "DrbdAvailVersionsForDist",
                          null, /* ProgressBar */
                          new ExecCallback() {
                            @Override
                            public void done(final String answer) {
                                allDone(answer);
                            }

                            @Override
                            public void doneError(final String answer,
                                                  final int errorCode) {
                                printErrorAndRetry(
                                    Tools.getString(
                                 "Dialog.Host.DrbdLinbitAvailPackages.NoArchs"),
                                        answer,
                                        errorCode);
                            }
                          },
                          null,   /* ConvertCmdCallback */
                          false,  /* outputVisible */
                          Ssh.DEFAULT_COMMAND_TIMEOUT);

        setCommandThread(t);
    }

    /**
     * Is called after all is done. It adds the listeners if it is the first
     * time it is called.
     */
    protected final void allDone(final String ans) {
        progressBarDone();

        enableComponents();
        if (ans == null) {
            final StringBuilder errorText = new StringBuilder(80);
            final String dist = getHost().getDistVersion();
            final String kernel = getHost().getKernelVersion();
            final String arch = getHost().getArch();
            if (drbdDistItems == null || !drbdDistItems.contains(dist)) {
                errorText.append(
                  Tools.getString(
                     "Dialog.Host.DrbdLinbitAvailPackages.NotAvailable.Dist"));
            } else if (drbdKernelDirItems == null
                       || !drbdKernelDirItems.contains(kernel)) {
                errorText.append(
                  Tools.getString(
                   "Dialog.Host.DrbdLinbitAvailPackages.NotAvailable.Kernel"));
            } else if (drbdArchItems == null || !drbdArchItems.contains(arch)) {
                errorText.append(
                  Tools.getString(
                    "Dialog.Host.DrbdLinbitAvailPackages.NotAvailable.Arch"));
            }
            errorText.append("\n\n");
            errorText.append(dist);
            errorText.append('\n');
            errorText.append(kernel);
            errorText.append('\n');
            errorText.append(arch);
            printErrorAndRetry(errorText.toString());
        } else {
            final String[] versions = ans.split(NEWLINE);
            getHost().setAvailableDrbdVersions(versions);
            answerPaneSetText(
                    Tools.getString(
                        "Dialog.Host.DrbdLinbitAvailPackages.AvailVersions")
                    + ' ' + Tools.join(", ", versions));
            if (Tools.getApplication().getAutoOptionHost("drbdinst") != null) {
                Tools.sleep(1000);
                pressNextButton();
            }
        }
        addListeners();
    }

    /** Inits dialog and starts the distribution detection. */
    @Override
    protected final void initDialogBeforeVisible() {
        super.initDialogBeforeVisible();
        enableComponentsLater(new JComponent[]{buttonClass(nextButton())});
    }

    /** Inits the dialog after it becomes visible. */
    @Override
    protected void initDialogAfterVisible() {
        availVersions();
    }

    /** Returns the next dialog which is CheckInstallation. */
    @Override
    public WizardDialog nextDialog() {
        if (getHost().isDrbdUpgraded()) {
            return new CheckInstallation(this, getHost());
        } else {
            return new DrbdAvailFiles(this, getHost());
        }
    }

    /**
     * Returns the title of the dialog. It is defined as
     * Dialog.Host.DrbdLinbitAvailPackages.Title in TextResources.
     */
    @Override
    protected final String getHostDialogTitle() {
        return Tools.getString("Dialog.Host.DrbdLinbitAvailPackages.Title");
    }

    /**
     * Returns the description of the dialog. It is defined as
     * Dialog.Host.DrbdLinbitAvailPackages.Description in TextResources.
     */
    @Override
    protected final String getDescription() {
        return Tools.getString(
                            "Dialog.Host.DrbdLinbitAvailPackages.Description");
    }

    /** Returns the pane with all combo boxes. */
    protected final JPanel getChoiceBoxes() {
        final JPanel pane = new JPanel();
        pane.setLayout(new BoxLayout(pane, BoxLayout.LINE_AXIS));
        final int maxX = (int) pane.getMaximumSize().getWidth();
        pane.setMaximumSize(new Dimension(maxX, CHOICE_BOX_HEIGHT));

        /* combo boxes */
        drbdDistCombo = WidgetFactory.createInstance(
                                       Widget.Type.COMBOBOX,
                                       Widget.NO_DEFAULT,
                                       Widget.NO_ITEMS,
                                       Widget.NO_REGEXP,
                                       0,    /* width */
                                       Widget.NO_ABBRV,
                                       new AccessMode(Application.AccessType.RO,
                                                      !AccessMode.ADVANCED),
                                       Widget.NO_BUTTON);

        drbdDistCombo.setEnabled(false);
        pane.add(drbdDistCombo.getComponent());
        drbdKernelDirCombo = WidgetFactory.createInstance(
                                       Widget.Type.COMBOBOX,
                                       Widget.NO_DEFAULT,
                                       Widget.NO_ITEMS,
                                       Widget.NO_REGEXP,
                                       0,    /* width */
                                       Widget.NO_ABBRV,
                                       new AccessMode(Application.AccessType.RO,
                                                      !AccessMode.ADVANCED),
                                       Widget.NO_BUTTON);

        drbdKernelDirCombo.setEnabled(false);
        pane.add(drbdKernelDirCombo.getComponent());
        drbdArchCombo = WidgetFactory.createInstance(
                                       Widget.Type.COMBOBOX,
                                       Widget.NO_DEFAULT,
                                       Widget.NO_ITEMS,
                                       Widget.NO_REGEXP,
                                       0,    /* width */
                                       Widget.NO_ABBRV,
                                       new AccessMode(Application.AccessType.RO,
                                                      !AccessMode.ADVANCED),
                                       Widget.NO_BUTTON);

        drbdArchCombo.setEnabled(false);
        pane.add(drbdArchCombo.getComponent());
        pane.add(Box.createHorizontalGlue());
        pane.add(Box.createRigidArea(new Dimension(10, 0)));
        return pane;
    }

    /** Adds listeners to the check boxes. */
    private void addListeners() {
        /* listeners, that disallow to select anything. */
        /* distribution combo box */
        drbdDistCombo.addListeners(
            new WidgetListener() {
                @Override
                public void check(final Value value) {
                    String v = getHost().getDistVersion();
                    if (drbdDistItems == null || !drbdDistItems.contains(v)) {
                        v = NO_MATCH_STRING;
                    }
                    drbdDistCombo.setValue(new StringValue(v));
                }
            });


        /* kernel version combo box */
        drbdKernelDirCombo.addListeners(
            new WidgetListener() {
                @Override
                public void check(final Value value) {
                    String v = getHost().getKernelVersion();
                    if (drbdKernelDirItems == null
                        || !drbdKernelDirItems.contains(v)) {
                        v = NO_MATCH_STRING;
                    }
                    drbdKernelDirCombo.setValue(new StringValue(v));
                }
            });

        /* arch combo box */
        drbdArchCombo.addListeners(
            new WidgetListener() {
                @Override
                public void check(final Value value) {
                    enableComponentsLater(
                                new JComponent[]{buttonClass(nextButton())});
                    getHost().setArch(drbdArchCombo.getStringValue());
                    availVersionsForDist();
                }
            });
    }

    /** Returns the input pane with check boxes and other info. */
    @Override
    protected final JComponent getInputPane() {
        final JPanel pane = new JPanel(new SpringLayout());
        final JPanel labelP = new JPanel(new FlowLayout(FlowLayout.LEADING));
        labelP.setPreferredSize(new Dimension(0, 0));
        labelP.add(new JLabel(
            Tools.getString(
                "Dialog.Host.DrbdLinbitAvailPackages.AvailablePackages")));
        pane.add(labelP);
        pane.add(getChoiceBoxes());
        final JPanel progrPane = getProgressBarPane();
        pane.add(progrPane);
        pane.add(getAnswerPane(Tools.getString(
                            "Dialog.Host.DrbdLinbitAvailPackages.Executing")));
        SpringUtilities.makeCompactGrid(pane, 4, 1,  // rows, cols
                                              0, 0,  // initX, initY
                                              0, 0); // xPad, yPad
        return pane;
    }
}
