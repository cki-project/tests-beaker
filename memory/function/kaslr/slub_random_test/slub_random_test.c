#include <linux/err.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/slab.h>


struct kmem_cache *slabtest_cache = NULL;
void *slabtest_buf = NULL;

static LIST_HEAD(to_free);

struct to_free_ptr {
	struct list_head free;
	void *ptr;
	void *padding;
};

static void free_objs(void)
{
	struct to_free_ptr *pos;
	struct to_free_ptr *n;
	int i = 0;
	list_for_each_entry_safe(pos, n, &to_free, free) {
		pr_info("freeing ptr%d=%px", i++, pos->ptr);
		kmem_cache_free(slabtest_cache, pos->ptr);
		kfree(pos);
	}
}

static int __init slabtest_init(void)
{
	int i;
	struct to_free_ptr *ptr;

	printk(KERN_ERR "init slabtest");
	slabtest_cache = kmem_cache_create("slabtest-32", 32, 0, 0, NULL);
	if (!slabtest_cache)
	{   printk(KERN_ERR "init slabtest failed");
		return -ENOMEM;
	}
	for (i=0; i<1000; i++) {
		slabtest_buf = kmem_cache_zalloc(slabtest_cache, GFP_KERNEL);
		if (!slabtest_buf)
		{   printk(KERN_ERR "init slabtest failed");
			return -ENOMEM;
		}
		pr_info("alloc ptr%d=%px", i, slabtest_buf);
		ptr = kmalloc(sizeof(*ptr), GFP_KERNEL);
		INIT_LIST_HEAD(&ptr->free);
		ptr->ptr = slabtest_buf;
		list_add(&ptr->free, &to_free);
	}

	return 0;
}

static void __exit slabtest_cleanup(void)
{
	printk(KERN_ERR "cleanup slabtest");
	free_objs();
	kmem_cache_destroy(slabtest_cache);
}



module_init(slabtest_init);
module_exit(slabtest_cleanup);
