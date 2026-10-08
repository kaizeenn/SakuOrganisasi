import { Router } from 'express';
import categoryController from '../controllers/category.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/', categoryController.list);
router.get('/:id', categoryController.get);
router.post('/', categoryController.create);
router.patch('/:id', categoryController.update);
router.delete('/:id', categoryController.remove);

export default router;
