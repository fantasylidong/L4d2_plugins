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
 * $Id: freelancer.php,v 1.2 2008/02/22 13:33:40 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Freelancer protocol
 * UNTESTED
 *
 * @author    Tom Buskens    <t.buskens@deviation.nl>
 * @version   $Revision: 1.2 $
 */
class GameQ_Protocol_freelancer extends GameQ_Protocol
{
    /*
     * status packet
     */
    public function status()
    {
        // Server name length @ 3
        $this->p->skip(3);
        $name_length = $this->p->readInt8() - 90;
        
        // Max players @ 20
        $this->p->skip(17);
        $this->r->add('max_players', $this->p->readInt8() - 1);
        // Num players @ 24
        $this->p->skip(3);
        $this->r->add('num_players', $this->p->readInt8() - 1);

        // Servername @ 91
        $this->p->skip(66);
        $this->r->add('servername', $this->p->read($name_length));
    }
}
?>
