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
 * $Id: redfaction.php,v 1.1 2007/06/30 12:43:43 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Red Faction Protocol
 *
 * @author     Tom Buskens   <t.buskens@deviation.nl>
 * @version    $Revision: 1.1 $
 */
class GameQ_Protocol_redfaction extends GameQ_Protocol
{
    /*
     * getstatus packet
     */
    public function status()
    {
        // Header, we're being carefull here
        if ($this->p->read() !== "\x00") {
            throw new GameQ_ParsingException($this->p);
        }
        
        // Dunno
        while ($this->p->read() !== "\x00") {}
        $this->p->read();

        // Data
        $this->r->add('servername',  $this->p->readString());
        $this->r->add('gametype',    $this->p->readInt8());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->r->add('map',         $this->p->readString());
        $this->p->read();
        $this->r->add('dedicated',   $this->p->readInt8());
    }
}
