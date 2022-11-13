<?php
/**
 * This file is part of GameQ.
 *
 * GameQ is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * GameQ is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * $Id: rfactor.php,v 1.2 2009/08/13 20:46:40 evilpie Exp $  
 */
 
require_once GAMEQ_BASE . 'Protocol.php';


/**
 * rFactor Protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.2 $
 */
class GameQ_Protocol_rfactor extends GameQ_Protocol
{

    public function status()
    {
        // Header
        $this->p->jumpto(17);
        $this->r->add('version', $this->p->readInt16());
        $this->p->jumpto(25);
        $this->r->add('series', $this->p->readString());
        $this->p->jumpto(45);
        $this->r->add('servername', $this->p->readString());

        $this->p->jumpto(73);
        $this->r->add('map', $this->p->readString());
        $this->p->jumpto(105);
        $this->r->add('motd', $this->p->readString());
        $this->p->jumpto(206);
        $this->r->add('rate', $this->p->readInt8());
        $this->r->add('numplayers', $this->p->readInt8());
        $this->r->add('maxplayers', $this->p->readInt8());
        $this->r->add('numbots', $this->p->readInt8());
        $this->r->add('session', $this->p->readInt8() >> 5);
        $this->r->add('damage', $this->p->readInt8());
        $this->p->jumpto(217);
        $this->r->add('time', $this->p->readInt16());
        $this->r->add('laps', $this->p->readInt16() / 16);
    }
}
?>
