<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DatabaseBackupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;
use Throwable;

class DatabaseRestoreController extends Controller
{
    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    public function restore(
        Request $request,
        DatabaseBackupService $backupService
    ): JsonResponse {
        $this->authorizeAdmin($request);

        $validated = $request->validate([
            'filename' => [
                'required',
                'string',
                'regex:/\Anana-wallet-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}\.sql\z/',
            ],
            'confirmation' => ['required', 'in:RESTORE DATABASE'],
        ]);

        try {
            // Validate the selected backup before changing anything.
            $backupPath = $backupService->getBackupPath(
                $validated['filename']
            );

            // Preserve the current database before restoring.
            $preRestoreBackup = $backupService->createBackup();

            $connectionName = config('database.default');
            $connection = config(
                "database.connections.{$connectionName}"
            );

            if (
                !in_array(
                    $connection['driver'] ?? null,
                    ['mysql', 'mariadb'],
                    true
                )
            ) {
                throw new \RuntimeException(
                    'Only MySQL/MariaDB restore is supported.'
                );
            }

            $database = $connection['database'] ?? null;
            $username = $connection['username'] ?? null;
            $password = (string) ($connection['password'] ?? '');
            $host = $connection['host'] ?? '127.0.0.1';
            $port = (string) ($connection['port'] ?? 3306);

            if (!$database || !$username) {
                throw new \RuntimeException(
                    'Database configuration is incomplete.'
                );
            }

            $binary = config(
                "database.connections.{$connectionName}.dump_binary",
                'mysqldump'
            );

            // Resolve mysql.exe next to mysqldump.exe when possible.
            $mysqlBinary = dirname($binary)
                . DIRECTORY_SEPARATOR . 'mysql.exe';

            if (!is_file($mysqlBinary)) {
                $mysqlBinary = 'mysql';
            }

            $process = new Process([
                $mysqlBinary,
                '--host=' . $host,
                '--port=' . $port,
                '--user=' . $username,
                '--default-character-set=utf8mb4',
                $database,
            ], base_path(), ['MYSQL_PWD' => $password]);

            $process->setTimeout(600);

            // Stream the private SQL backup to the MySQL client.
            $handle = fopen($backupPath, 'rb');

            if ($handle === false) {
                throw new \RuntimeException(
                    'Could not open the selected backup.'
                );
            }

            try {
                $process->setInput($handle);
                $process->run();
            } finally {
                fclose($handle);
            }

            if (!$process->isSuccessful()) {
                throw new \RuntimeException(
                    'MySQL could not restore the selected backup.'
                );
            }

            Log::warning('Database restore completed.', [
                'admin_user_id' => $request->user()->id,
                'restored_filename' => $validated['filename'],
                'pre_restore_backup' => $preRestoreBackup['filename'],
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Database restore completed successfully.',
                'data' => [
                    'restored_filename' => $validated['filename'],
                    'safety_backup' => $preRestoreBackup['filename'],
                ],
            ]);
        } catch (Throwable $exception) {
            Log::error('Database restore failed.', [
                'admin_user_id' => $request->user()->id,
                'exception_class' => get_class($exception),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Database restore failed. Check the server logs and safety backup before retrying.',
            ], 500);
        }
    }
}