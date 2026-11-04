<?php

namespace App\Services;

use RuntimeException;
use Symfony\Component\Process\Process;
use Throwable;

class DatabaseBackupService
{
    public function createBackup(): array
    {
        $connectionName = config('database.default');
        $connection = config("database.connections.{$connectionName}");

        if (!in_array($connection['driver'] ?? null, ['mysql', 'mariadb'], true)) {
            throw new RuntimeException(
                'Database backups currently support MySQL and MariaDB only.'
            );
        }

        $database = $connection['database'] ?? null;
        $username = $connection['username'] ?? null;
        $password = $connection['password'] ?? '';
        $host = $connection['host'] ?? '127.0.0.1';
        $port = (string) ($connection['port'] ?? 3306);

        if (!$database || !$username) {
            throw new RuntimeException(
                'Database connection configuration is incomplete.'
            );
        }

        $binary = config(
            "database.connections.{$connectionName}.dump_binary",
            'mysqldump'
        );

        $directory = storage_path('app/private/database-backups');

        if (
            !is_dir($directory) &&
            !mkdir($directory, 0700, true) &&
            !is_dir($directory)
        ) {
            throw new RuntimeException(
                'Could not create the private backup directory.'
            );
        }

        $filename = 'nana-wallet-' .
            now()->format('Ymd-His') . '-' .
            bin2hex(random_bytes(4)) . '.sql';

        $path = $directory . DIRECTORY_SEPARATOR . $filename;

        $command = [
            $binary,
            '--host=' . $host,
            '--port=' . $port,
            '--user=' . $username,
            '--single-transaction',
            '--quick',
            '--skip-lock-tables',
            '--routines',
            '--triggers',
            '--default-character-set=utf8mb4',
            $database,
        ];

        $process = new Process(
            $command,
            base_path(),
            ['MYSQL_PWD' => (string) $password]
        );

        $process->setTimeout(300);

        try {
            $process->run();

            if (!$process->isSuccessful()) {
                throw new RuntimeException(
                    'Database backup failed. Check that mysqldump is installed, ' .
                    'its configured path is correct, and the database user has ' .
                    'permission to export the database.'
                );
            }

            $sql = $process->getOutput();

            if (trim($sql) === '') {
                throw new RuntimeException(
                    'The database backup command returned an empty result.'
                );
            }

            if (file_put_contents($path, $sql, LOCK_EX) === false) {
                throw new RuntimeException(
                    'Could not save the database backup.'
                );
            }

            @chmod($path, 0600);

            return [
                'filename' => $filename,
                'size_bytes' => filesize($path),
                'sha256' => hash_file('sha256', $path),
                'created_at' => now()->toIso8601String(),
            ];
        } catch (Throwable $exception) {
            if (is_file($path)) {
                @unlink($path);
            }

            throw $exception;
        }
    }

    public function listBackups(): array
    {
        $directory = storage_path('app/private/database-backups');

        if (!is_dir($directory)) {
            return [];
        }

        $files = glob($directory . DIRECTORY_SEPARATOR . 'nana-wallet-*.sql')
            ?: [];

        $backups = [];

        foreach ($files as $path) {
            if (!is_file($path) || is_link($path)) {
                continue;
            }

            $backups[] = [
                'filename' => basename($path),
                'size_bytes' => filesize($path),
                'sha256' => hash_file('sha256', $path),
                'created_at' => date(DATE_ATOM, filemtime($path)),
            ];
        }

        usort(
            $backups,
            fn(array $a, array $b) =>
                strcmp($b['created_at'], $a['created_at'])
        );

        return $backups;
    }

    public function getBackupPath(string $filename): string
    {
        if (!preg_match('/\Anana-wallet-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}\.sql\z/', $filename)) {
            throw new RuntimeException('Invalid backup filename.');
        }

        $path = storage_path(
            'app/private/database-backups/' . $filename
        );

        if (!is_file($path) || is_link($path)) {
            throw new RuntimeException('Backup file not found.');
        }

        return $path;
    }
}