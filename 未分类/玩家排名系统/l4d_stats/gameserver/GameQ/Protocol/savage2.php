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
 * $Id: savage2.php,v 1.1 2008/05/22 14:16:11 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Savage 2 Protocol
 *
 * @author         Tom Buskens    <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_savage2 extends GameQ_Protocol
{
    /*
     * status packet
     */
    public function status()
    {
        $this->p->skip(12);
        $this->r->add('hostname',    $this->p->readString());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('time',        $this->p->readString());
        $this->r->add('map',         $this->p->readString());
        $this->r->add('nextmap',     $this->p->readString());
        $this->r->add('location',    $this->p->readString());
        $this->r->add('min_players', $this->p->readInt8());
        $this->r->add('gametype',    $this->p->readString());
        $this->r->add('version',     $this->p->readString());
        $this->r->add('min_level',   $this->p->readInt8());
    }
}
?>
