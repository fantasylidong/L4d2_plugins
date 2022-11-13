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
 * $Id: cs2d.php,v 1.1 2008/04/14 18:04:50 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Counterstrike 2d Protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_cs2d extends GameQ_Protocol
{
    public function status()
    {
        $this->p->skip(2);
        $this->r->add('hostname',    $this->readString());
        $this->r->add('password',    $this->p->readInt8());
        $this->r->add('mapname',     $this->readString());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('fog_of_war',  $this->p->readInt8());
        $this->r->add('war_mode',    $this->p->readInt8());
        $this->r->add('version',     $this->readString());
    }

    private function readString()
    {
        $str = $this->p->readString("\x0D");
        $this->p->skip(1);
        return $str;
    }
}
?>
