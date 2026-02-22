CREATE TABLE IF NOT EXISTS `md_gangs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `label` VARCHAR(50) NOT NULL,
    `grades` LONGTEXT NOT NULL,
    `cloakroom` LONGTEXT DEFAULT NULL,
    `garage_spawn` LONGTEXT DEFAULT NULL,
    `garage_store` LONGTEXT DEFAULT NULL,
    `stash` LONGTEXT DEFAULT NULL,
    `boss` LONGTEXT DEFAULT NULL,
    `vehicles` LONGTEXT DEFAULT NULL,
    `permissions` LONGTEXT DEFAULT NULL,
    `webhook` VARCHAR(255) DEFAULT NULL,
    `color` INT DEFAULT 0,
    `blip_enabled` TINYINT DEFAULT 0,
    `blip_visibility` VARCHAR(20) DEFAULT 'members',
    `marker_type` INT DEFAULT 1,
    `outfits` LONGTEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `md_gang_members` (
    `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
    `gang` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
