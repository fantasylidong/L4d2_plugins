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
 * $Id: hexen2.php,v 1.1 2007/07/11 09:12:31 tombuskens Exp $  
 */
 
 
require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Hexen 2 protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.1 $
 */
class GameQ_Protocol_hexen2 extends GameQ_Protocol
{
    /*
     * status packet
     */
    public function status()
    {
        // Header?
        $this->p->skip(5);

        $this->r->add('address',     $this->p->readString());
        $this->r->add('servername',  $this->p->readString());
        $this->r->add('map',         $this->p->readString());
        $this->r->add('num_players', $this->p->readInt8());
        $this->r->add('max_players', $this->p->readInt8());
        $this->p->skip(); // unknown
    }
}
?>
