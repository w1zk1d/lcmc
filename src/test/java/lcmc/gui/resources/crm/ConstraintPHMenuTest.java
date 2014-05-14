/*
 * This file is part of LCMC written by Rasto Levrinc.
 *
 * Copyright (C) 2014, Rastislav Levrinc.
 *
 * The LCMC is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * The LCMC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LCMC; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

package lcmc.gui.resources.crm;

import java.util.List;
import lcmc.data.resources.Service;
import lcmc.gui.ClusterBrowser;
import lcmc.utilities.Tools;
import lcmc.utilities.UpdatableItem;
import static org.junit.Assert.assertEquals;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import static org.mockito.Mockito.when;
import org.mockito.runners.MockitoJUnitRunner;

@RunWith(MockitoJUnitRunner.class)
public class ConstraintPHMenuTest {
    static {
        Tools.init();
    }

    @Mock
    private ConstraintPHInfo constraintPHInfoStub;
    @Mock
    private ClusterBrowser clusterBrowserStub;
    @Mock
    private Service serviceStub;

    private ConstraintPHMenu sut;

    @Before
    public void setUp() {
        when(constraintPHInfoStub.getBrowser()).thenReturn(clusterBrowserStub);
        when(constraintPHInfoStub.getService()).thenReturn(serviceStub);
        sut = new ConstraintPHMenu(constraintPHInfoStub);
    }

    @Test
    public void menuShouldHaveItems() {
        final List<UpdatableItem> items = sut.getPulldownMenu();

        assertEquals(4, items.size());
    }

}