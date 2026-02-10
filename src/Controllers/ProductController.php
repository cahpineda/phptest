<?php

namespace Controllers;

/**
 * Product Controller
 * Maneja operaciones de productos
 */
class ProductController
{
    private $repository;

    public function __construct($repository)
    {
        $this->repository = $repository;
    }

    public function listProducts(): array
    {
        return $this->repository->findAll();
    }

    public function getProduct(int $id): ?array
    {
        return $this->repository->findById($id);
    }

    public function createProduct(array $data): bool
    {
        if (empty($data['name']) || empty($data['price'])) {
            return false;
        }

        return $this->repository->create($data);
    }
}
