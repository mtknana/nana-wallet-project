<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DatabaseBackupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Throwable;

class DatabaseBackupController extends Controller
{
    private function authorizeAdmin(Request $request): void
    {
        abort_unless(
            $request->user()?->role === 'admin',
            403,
            'Administrator access required.'
        );
    }

    public function index(
        Request $request,
        DatabaseBackupService $service
    ): JsonResponse {
        $this->authorizeAdmin($request);

        return response()->json([
            'status' => 'success',
            'data' => $service->listBackups(),
        ]);
    }

    public function store(
        Request $request,
        DatabaseBackupService $service
    ): JsonResponse {
        $this->authorizeAdmin($request);

        try {
            $backup = $service->createBackup();

            Log::info('Database backup created.', [
                'admin_user_id' => $request->user()->id,
                'filename' => $backup['filename'],
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Database backup created successfully.',
                'data' => $backup,
            ], 201);
        } catch (Throwable $exception) {
            Log::error('Database backup failed.', [
                'admin_user_id' => $request->user()->id,
                'exception_class' => get_class($exception),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'The database backup could not be created. Check the server logs.',
            ], 500);
        }
    }

    public function download(
        Request $request,
        string $filename,
        DatabaseBackupService $service
    ): BinaryFileResponse {
        $this->authorizeAdmin($request);

        try {
            $path = $service->getBackupPath($filename);
        } catch (\RuntimeException $exception) {
            abort(404, 'Backup file not found.');
        }

        return response()->download($path, $filename, [
            'Cache-Control' => 'no-store, private',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}