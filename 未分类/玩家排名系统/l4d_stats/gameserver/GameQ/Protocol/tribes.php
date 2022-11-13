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
 * $Id: tribes.php,v 1.1 2007/07/07 14:20:21 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Tribes protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_tribes extends GameQ_Protocol
{
    public function status()
    {
        // Header
        if ($this->p->read(4) != 'c++b') {
            throw new GameQ_ParsingException($this->p);
        }

        // Variables
        $this->r->add('game',        $this->p->readPascalString());
        $this->r->add('version',     $this->p->readPascalString());
        $this->r->add('hostname',    $this->p->readPascalString());
        $this->r->add('dedicated',   $this->p->readInt8());
        $this->r->add('password',    $this->p->readInt8());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('cpu_lsb',     $this->p->readInt8());
        $this->r->add('cpu_msb',     $this->p->readInt8());
        $this->r->add('mod',         $this->p->readPascalString());
        $this->r->add('gametype',    $this->p->readPascalString());
        $this->r->add('map',         $this->p->readPascalString());
        $this->r->add('motd',        $this->p->readPascalString());
        $this->r->add('teamcount',   $this->p->readInt8());         // Not sure

        // TODO: player listing
    }
}
?>

