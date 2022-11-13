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
 * $Id: ghostrecon.php,v 1.1 2007/07/02 10:14:32 tombuskens Exp $  
 */


require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Ghost Recon protocol
 *
 * @author          Tom Buskens    <t.buskens@deviation.nl>
 * @version         $Revision: 1.1 $
 */
class GameQ_Protocol_ghostrecon extends GameQ_Protocol
{
    /*
     * Status
     */
    public function status()
    {
        // Unknown
        $this->p->skip(25);

        $this->r->add('servername', $this->readGhostString());
        $this->r->add('map',        $this->readGhostString());
        $this->r->add('mission',    $this->readGhostString());
        $this->r->add('gametype',   $this->readGhostString());
    }

    /**
     * Read a Ghost Recon string
     *
     * @return   string    The string
     */
    private function readGhostString()
    {
        if ($this->p->getLength() < 4) return '';
        $this->p->skip(4);

        return $this->p->readString();
        
    }
}
?>
